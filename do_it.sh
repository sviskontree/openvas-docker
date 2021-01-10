#!/bin/bash
#add check for psql files
#pg_ctlcluster 12 openvas start
pg_createcluster 12 openvas --start
sleep 8
sudo -u postgres createuser openvas
sudo -u postgres createdb -O openvas gvmd
sudo -u postgres psql -d gvmd -c "CREATE EXTENSION \"uuid-ossp\";"
sudo -u postgres psql -d gvmd -c "CREATE EXTENSION \"pgcrypto\";"
sudo -u postgres psql -d gvmd -c "CREATE ROLE dba WITH SUPERUSER NOINHERIT;"
sudo -u postgres psql -d gvmd -c "GRANT dba TO openvas;"
sudo -u openvas gvmd --migrate

mkdir -p /var/run/{ospd,gvmd} && chown openvas /var/run/{ospd,gvmd}
mkdir -p /var/run/redis
redis-server /etc/redis/redis.conf
echo "Testing redis status..."
X="$(redis-cli -s /var/run/redis/redis.sock ping)"
while  [ "${X}" != "PONG" ]; do
        echo "Redis not yet ready..."
        sleep 1
        X="$(redis-cli -s /var/run/redis/redis.sock ping)"
done
echo "Redis ready."

if [ ! -f /usr/local/var/lib/gvm/CA/servercert.pem ]; then
	sudo -u openvas gvm-manage-certs -a
fi

sudo -u openvas gvmd --rebuild-scap

cd /tmp/
sudo -u openvas nohup ospd-openvas -f -c /usr/local/var/lib/gvm/CA/servercert.pem --ca-file /usr/local/var/lib/gvm/CA/cacert.pem -k /usr/local/var/lib/gvm/private/CA/serverkey.pem -u /var/run/ospd/ospd.sock --pid-file /var/run/ospd/ospd.pid &
sleep 6 
sudo -u openvas nohup gvmd -f -c /var/run/gvmd/gvmd.sock &
sudo -u openvas nohup gsad -f --munix-socket=/var/run/gvmd/gvmd.sock &

sleep 5
mkdir -p /usr/local/var/lib/gvm/gvmd/report_formats/ && chmod 755  /usr/local/var/lib/gvm/gvmd/report_formats/ && chown -R openvas /usr/local/var/lib/gvm/gvmd/
#Remove hardcoded password + user......
sudo -u openvas gvmd --create-user=admin --password=admin
sudo -u openvas gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value $(sudo -u openvas gvmd --get-users --verbose | awk '{print $2}')
sudo -u openvas gvmd --rebuild
tail -f /usr/local/var/log/gvm/*
