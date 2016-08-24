Keystone with SSL
=================
[![](https://images.microbadger.com/badges/image/clearlinux/keystone.svg)](http://microbadger.com/images/clearlinux/keystone "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/clearlinux/keystone.svg)](http://microbadger.com/images/clearlinux/keystone "Get your own version badge on microbadger.com")

This provides a SSL-enabled Keystone docker container

Build
-----
```
    docker build -t clearlinux/keystone .
```

Or just pull it from Dockerhub
---------------------------
```
    docker pull clearlinux/keystone
```

Create Keystone SSL certificates
--------------------------------
```
    YOUR_HOST=`hostname -f`
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout keystone_key.pem \
                -out keystone_cert.pem -subj "/CN=$YOUR_HOST"
```

Start Keystone container
------------------------
```
    YOUR_HOST=`hostname -f`
    docker run -d -it --name keystone -p 5000:5000 -p 35357:35357 \
		   -e IDENTITY_HOST="$YOUR_HOST" \
		   -e KEYSTONE_DB_USER="keystone" \
		   -e KEYSTONE_DB_PASSWORD="secret" \
		   -e KEYSTONE_DB_NAME="keystone" \
		   -e KEYSTONE_ADMIN_PASSWORD="secret" \
		   -v `pwd`/keystone_cert.pem:/etc/nginx/ssl/keystone_cert.pem \
		   -v `pwd`/keystone_key.pem:/etc/nginx/ssl/keystone_key.pem \
		   clearlinux/keystone
```

Login into Keystone container
------------------------------
```
    docker exec -it  keystone bash
    # Inside the container
    root@26bd2b8a8a60 /root # source openrc
    openstack user list
    +----------------------------------+-------+
    | ID                               | Name  |
    +----------------------------------+-------+
    | 24620586335a473fb56fc2be2f6bfb53 | admin |
    +----------------------------------+-------+
```

Environment Variables
---------------------
- ``IDENTITY_HOST``
  Identity (Keystone) host
- ``KEYSTONE_DB_USER``
  Keystone database username
- ``KEYSTONE_DB_PASSWORD``
  Keystone database password
- ``KEYSTONE_DB_NAME``
  Keystone database name
- ``KEYSTONE_ADMIN_PASSWORD``
  Keystone Admin user password

Extra Build ARGs
----------------
- ``swupd_args`` Specifies [SWUPD](https://clearlinux.org/documentation/swupdate_how_to_run_the_updater.html) flags

Default build args in Docker are on: https://docs.docker.com/engine/reference/builder/#/arg