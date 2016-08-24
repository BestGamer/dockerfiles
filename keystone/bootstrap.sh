#!/bin/bash

IDENTITY_HOST=localhost
KEYSTONE_DB_USER=keystone
KEYSTONE_DB_PASSWORD=914de29bc82616d7c159eaf9b1f39402
KEYSTONE_DB_NAME=keystone
KEYSTONE_ADMIN_PASSWORD="${KEYSTONE_ADMIN_PASSWORD:-bb915e9ce0ae4b46e82a069b2ef0f8d7}"

sed -i.bak s/IDENTITY_HOST/$IDENTITY_HOST/g /root/openrc
sed -i.bak s/KEYSTONE_ADMIN_PASSWORD/$KEYSTONE_ADMIN_PASSWORD/g /root/openrc
sed -i.bak s/MARIADB_HOST/$MARIADB_HOST/g /etc/keystone/keystone.conf
sed -i.bak s/KEYSTONE_DB_USER/$KEYSTONE_DB_USER/g /etc/keystone/keystone.conf
sed -i.bak s/KEYSTONE_DB_PASSWORD/$KEYSTONE_DB_PASSWORD/g /etc/keystone/keystone.conf
sed -i.bak s/KEYSTONE_DB_NAME/$KEYSTONE_DB_NAME/g /etc/keystone/keystone.conf
sed -i.bak s/IDENTITY_HOST/$IDENTITY_HOST/g /etc/nginx/keystone.wsgi.conf

# MariaDB
# Bootstrap mariadb if it hasn't been started
if [[ ! -d /var/lib/mysql/mysql ]]; then
    /usr/bin/mysql-systemd-start pre
    mysqld_safe &
    mysqladmin --silent --wait=30 ping || exit 1

    # Set root user password
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO \"root\"@\"%\" IDENTIFIED by \"secret\" WITH GRANT OPTION;"

    # Remove anonymous user access
    mysql -e "DELETE FROM mysql.user WHERE User=\"\";"

    # Remove test database
    mysql -e "DROP DATABASE test;"

    # Keystone Database and user
    mysql -e "create database $KEYSTONE_DB_NAME;"
    mysql -e "grant all on $KEYSTONE_DB_NAME.* to '$KEYSTONE_DB_USER'@'%' identified by '$KEYSTONE_DB_PASSWORD';"
    mysql -e "grant all on $KEYSTONE_DB_NAME.* to '$KEYSTONE_DB_USER'@'localhost' identified by '$KEYSTONE_DB_PASSWORD';"
fi

# Populate keystone database
keystone-manage db_sync

# Nginx & UWSGI
mkdir -p /run/uwsgi/keystone
sed -i 's/uid.*/ /' /usr/share/uwsgi/keystone/{public,admin}.ini
sed -i 's/gid.*/ /' /usr/share/uwsgi/keystone/{public,admin}.ini
echo "logto=/var/log/uwsgi-keystone-admin.log" >> /usr/share/uwsgi/keystone/admin.ini
echo "logto=/var/log/uwsgi-keystone-public.log" >> /usr/share/uwsgi/keystone/public.ini
/usr/bin/uwsgi --ini /usr/share/uwsgi/keystone/admin.ini -s /run/uwsgi/keystone/admin.sock &
/usr/bin/uwsgi --ini /usr/share/uwsgi/keystone/public.ini -s /run/uwsgi/keystone/public.sock &

mkdir /var/lib/nginx
echo "user  root;" >> /usr/share/nginx/conf/nginx.conf
/usr/bin/nginx

/usr/bin/memcached -u root &

# Bootstrap keystone
keystone-manage bootstrap --bootstrap-username admin \
		--bootstrap-password $KEYSTONE_ADMIN_PASSWORD \
		--bootstrap-project-name admin \
		--bootstrap-role-name admin \
		--bootstrap-service-name keystone \
		--bootstrap-admin-url "https://$IDENTITY_HOST:35357/v3" \
		--bootstrap-public-url "https://$IDENTITY_HOST:5000/v3" \
		--bootstrap-internal-url "https://$IDENTITY_HOST:5000/v3"

source /root/openrc
# Create 'service' project if it does not exists
openstack project show service
if [[ $? == 1 ]]; then
    openstack project create --domain default --description "Service Project" service
fi

# Create 'user' role
openstack role show user
if [[ $? == 1 ]]; then
    openstack role create user
fi

tail -f /var/log/*
