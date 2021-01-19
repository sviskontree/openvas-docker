FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV PKG_CONFIG_PATH=/usr/lib64/pkgconfig:$PKG_CONFIG_PATH
ENV VERSION=20.8.0

VOLUME ["/usr/local/var/lib/gvm/gvmd"]
VOLUME ["/var/lib/postgresql/12/openvas"]

RUN apt-get update && apt-get install bison cmake gcc git gnutls-bin libgcrypt20-dev libglib2.0-dev libgnutls28-dev libgpgme-dev libhiredis-dev libical-dev libksba-dev libldap2-dev libpcap-dev libradcli-dev libsnmp-dev libssh-gcrypt-dev libxml2-dev pkg-config postgresql-client python3-pip uuid-dev xml-twig-tools xsltproc libmicrohttpd-dev nodejs npm nmap wget rsync sudo libcap2-bin libpq5 libpq-dev postgresql-server-dev-12 socat -y && python3 -m pip install ospd && groupadd openvas -g 9119 && useradd openvas -u 9119 -g openvas -N -s /bin/bash

COPY files/lib64 /etc/ld.so.conf.d/lib64
COPY files/10-openvas /etc/sudoers.d/10-openvas

WORKDIR /opt

RUN wget https://github.com/greenbone/gvm-libs/archive/v${VERSION}.tar.gz -O gvm-libs-v${VERSION}.tar.gz && tar -xvzf gvm-libs-v${VERSION}.tar.gz && cd gvm-libs-${VERSION} && cmake -DCMAKE_INSTALL_PREFIX=/usr . && make && make install && cd .. && rm -rf *
RUN wget https://github.com/greenbone/openvas/archive/v${VERSION}.tar.gz -O openvas-v${VERSION}.tar.gz && tar -xvzf openvas-v${VERSION}.tar.gz && cd openvas-${VERSION} && cmake . && make && make install && cp /usr/local/lib/libopenvas_* /usr/lib/ && cd .. && rm -rf *
RUN wget https://github.com/greenbone/gvmd/archive/v${VERSION}.tar.gz -O gvmd-v${VERSION}.tar.gz && tar -xvzf gvmd-v${VERSION}.tar.gz && cd gvmd-${VERSION} && cmake -DPostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql . && make && make install && mv /usr/lib64/libgvm* /usr/lib/ && mv /usr/lib64/pkgconfig/libgvm* /usr/lib/pkgconfig/ && cd .. && rm -rf *
RUN wget https://github.com/greenbone/ospd-openvas/archive/v${VERSION}.tar.gz -O ospd-openvas-v${VERSION}.tar.gz && tar -xvzf ospd-openvas-v${VERSION}.tar.gz && cd ospd-openvas-${VERSION} && python3 setup.py install && cd .. && rm -rf *

RUN wget https://github.com/greenbone/gsa/archive/v${VERSION}.tar.gz -O gsa-v${VERSION}.tar.gz && tar -xvzf gsa-v${VERSION}.tar.gz && cd gsa-${VERSION} && cmake . && make && make install && cd .. && rm -rf *

RUN mkdir -p /usr/local/var/run && chown -R openvas /usr/local/var/ && chown openvas /usr/local/var/lib/openvas/plugins && mkdir -p /usr/etc/gvm && cp /usr/local/etc/gvm/pwpolicy.conf /usr/etc/gvm/ && chown openvas -R /usr/etc/ && chown openvas /usr/var/run/

USER openvas
RUN greenbone-nvt-sync
RUN greenbone-feed-sync --type GVMD_DATA
RUN greenbone-feed-sync --type SCAP
RUN greenbone-feed-sync --type CERT
USER root

COPY files/do_it.sh /do_it.sh
RUN setcap cap_net_bind_service=+ep /usr/local/sbin/gsad && chmod 440 /etc/sudoers.d/10-openvas && chmod u+x /do_it.sh
CMD /do_it.sh
