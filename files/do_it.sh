#!/bin/bash
mkdir -p /var/run/{postgresql,redis,ospd,gvmd}
chown openvas /var/run/{ospd,gvmd,postgresql,redis}

sleep 4
sudo -u openvas nohup socat UNIX-LISTEN:/var/run/redis/redis.sock,fork tcp:${REDIS_SERVER:-redis}:${REDIS_PORT:-6379} &
sudo -u openvas nohup socat UNIX-LISTEN:/var/run/postgresql/.s.PGSQL.5432,fork tcp:${POSTGRES_SERVER:-psql}:${POSTGRES_PORT:-5432} &
sudo -u openvas psql -U ${POSTGRES_USER:-openvas} -h /var/run/postgresql/ -d gvmd -c "CREATE EXTENSION \"uuid-ossp\";"
sudo -u openvas psql -U ${POSTGRES_USER:-openvas} -h /var/run/postgresql/ -d gvmd -c "CREATE EXTENSION \"pgcrypto\";"
sudo -u openvas psql -U ${POSTGRES_USER:-openvas} -h /var/run/postgresql/ -d gvmd -c "CREATE ROLE dba WITH SUPERUSER NOINHERIT;"
sudo -u openvas psql -U ${POSTGRES_USER:-openvas} -h /var/run/postgresql/ -d gvmd -c "GRANT dba TO openvas;"

sleep 8
sudo -u openvas gvmd --migrate

if [ ! -f /usr/local/var/lib/gvm/CA/servercert.pem ]; then
        sudo -u openvas gvm-manage-certs -a
fi

echo "Gmvd will now rebuild-scap data, it will take a while"
sudo -u openvas gvmd --rebuild-scap

cd /tmp/
echo "Starting ospd-openvas"
sudo -u openvas nohup ospd-openvas -f -c /usr/local/var/lib/gvm/CA/servercert.pem --ca-file /usr/local/var/lib/gvm/CA/cacert.pem -k /usr/local/var/lib/gvm/private/CA/serverkey.pem -u /var/run/ospd/ospd.sock --pid-file /var/run/ospd/ospd.pid &
sleep 12
echo "Starting gvmd and gsad"
sudo -u openvas nohup gvmd -f -c /var/run/gvmd/gvmd.sock &
sudo -u openvas nohup gsad -f --munix-socket=/var/run/gvmd/gvmd.sock &

sleep 8
mkdir -p /usr/local/var/lib/gvm/gvmd/report_formats/ && chmod 755  /usr/local/var/lib/gvm/gvmd/report_formats/ && chown -R openvas /usr/local/var/lib/gvm/gvmd/

sudo -u openvas gvmd --get-users | grep -q ${OPENVAS_ADMIN_USER:-admin}
if [ $? != 0 ]; then
        sudo -u openvas gvmd --create-user=${OPENVAS_ADMIN_USER:-admin} --password=${OPENVAS_ADMIN_PW:-admin}
        sudo -u openvas gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value $(sudo -u openvas gvmd --get-users --verbose | awk '{print $2}')
fi

sudo -u openvas gvmd --rebuild
echo -e "\nOpenvas should now be starting\nIf this is the first time you are running, it will be a while before import of all data is done\n"
tail -f /usr/local/var/log/gvm/*
