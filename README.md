Two docker containers to run Openvas, the build includes everything needed for it to run.

Usage
-----

The easiest way to run it is with docker-compose. The below example will create one openvas containers that runs gui + scanning, it creates persistence in the same directory as ran from. A separate postgresql container with the user openvas and the db gvmd aswell as the option POSTGRES_HOST_AUTH_METHOD is run. These options are currently a requirement for it to run.

```
version: '3.2'

services:
  openvas:
    image: sviskontree/openvas:v20.8.0
    volumes:
      - ./gvmd:/usr/local/var/lib/gvm/gvmd
    ports:
      - 443:443
    depends_on:
      - psql

  psql:
    image: sviskontree/openvas-postgresql:v20.8.0
    restart: always
    volumes:
      - ./postgres:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: openvas
      POSTGRES_DB: gvmd
      POSTGRES_HOST_AUTH_METHOD: trust
```

Environment variables
-----

Name     | Description | Default
---------|------------|-----------
OPENVAS_ADMIN_USER | admin user used for login to webgui | admin
OPENVAS_ADMIN_PW | password for the admin user | admin
POSTGRES_USER | user to use when connecting with the postgresql database (should not be changed) | openvas
POSTGRES_SERVER | postgres server name/ip | psql
POSTGRES_PORT | postgres port to connect to | 5432

For options available to the postgresql container see [postgres](https://hub.docker.com/_/postgres) on dockerhub

Extra
------
Openvas made by [Greenbone](https://github.com/greenbone/)

Heavily inspired by Mikesplains [openvas-docker](https://github.com/mikesplain/openvas-docker)
