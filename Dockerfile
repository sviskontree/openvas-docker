FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV PKG_CONFIG_PATH=/usr/lib64/pkgconfig:$PKG_CONFIG_PATH
ENV NMAP_PRIVILEGED=""

VOLUME ["/usr/local/var/lib/gvm/gvmd"]
VOLUME ["/var/lib/postgresql/12/openvas"]

RUN apt-get update && apt-get install bison cmake gcc git gnutls-bin libgcrypt20-dev libglib2.0-dev libgnutls28-dev libgpgme-dev libhiredis-dev libical-dev libksba-dev libldap2-dev libpcap-dev libpq-dev libradcli-dev libsnmp-dev libssh-gcrypt-dev libxml2-dev pkg-config postgresql postgresql-contrib postgresql-server-dev-all python3-pip redis-server uuid-dev xml-twig-tools xsltproc libmicrohttpd-dev nodejs npm nmap wget rsync sudo libcap2-bin -y && python3 -m pip install ospd && groupadd openvas -g 9119 && useradd openvas -u 9119 -g openvas -N -s /bin/bash

COPY redis.conf /etc/redis/redis.conf
COPY lib64 /etc/ld.so.conf.d/lib64
COPY 10-openvas /etc/sudoers.d/10-openvas

RUN cd /opt/ && wget https://github.com/greenbone/gvm-libs/archive/v20.8.0.tar.gz -O gvm-libs-v20.8.0.tar.gz && wget https://github.com/greenbone/openvas/archive/v20.8.0.tar.gz -O openvas-v20.8.0.tar.gz && wget https://github.com/greenbone/gvmd/archive/v20.8.0.tar.gz -O gvmd-v20.8.0.tar.gz && wget https://github.com/greenbone/ospd-openvas/archive/v20.8.0.tar.gz -O ospd-openvas-v20.8.0.tar.gz && wget https://github.com/greenbone/gsa/archive/v20.8.0.tar.gz -O gsa-v20.8.0.tar.gz && tar -xvzf gvm-libs-v20.8.0.tar.gz && cd gvm-libs-20.8.0 && cmake -DCMAKE_INSTALL_PREFIX=/usr . && make && make install && cd .. && tar -xvzf openvas-v20.8.0.tar.gz && cd openvas-20.8.0 && cmake . && make && make install && cp /usr/local/lib/libopenvas_* /usr/lib/ && cd .. && tar -xvzf gvmd-v20.8.0.tar.gz && cd gvmd-20.8.0 && cmake . && make && make install && mv /usr/lib64/libgvm* /usr/lib/ && mv /usr/lib64/pkgconfig/libgvm* /usr/lib/pkgconfig/ && cd .. && tar -xvzf ospd-openvas-v20.8.0.tar.gz && cd ospd-openvas-20.8.0 && python3 setup.py install && cd .. && tar -xvzf gsa-v20.8.0.tar.gz && cd gsa-20.8.0 && cmake . && make && make install && cd .. && rm -rf *

RUN mkdir -p /usr/local/var/run && chown -R openvas /usr/local/var/ && chown openvas /usr/local/var/lib/openvas/plugins && mkdir -p /usr/etc/gvm && cp /usr/local/etc/gvm/pwpolicy.conf /usr/etc/gvm/ && chown openvas -R /usr/etc/ && chown openvas /usr/var/run/

USER openvas
RUN greenbone-nvt-sync
RUN greenbone-feed-sync --type GVMD_DATA
RUN greenbone-feed-sync --type SCAP
RUN greenbone-feed-sync --type CERT
USER root

COPY do_it.sh /do_it.sh
RUN pg_dropcluster --stop 12 main && setcap cap_net_bind_service=+ep /usr/local/sbin/gsad && chmod 440 /etc/sudoers.d/10-openvas && chmod u+x /do_it.sh
CMD /do_it.sh
