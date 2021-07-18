#!/bin/bash

# For testing:
# rm -rf nextcloud-snap
# git clone --branch prettyurl https://github.com/nextcloud/nextcloud-snap.git
# cd nextcloud-snap

# Stop if something fails
set -e

# Get the correct tar file from the branch itself
NC_DOMAIN="$(grep 'https://download.nextcloud.com/server' ./snap/snapcraft.yaml | grep -oP 'https://.*')"

# Download the tar file
curl -fL "$NC_DOMAIN" -o /tmp/ncpackage.tar.bz2

# Extract the archive
mkdir -p /tmp/nc
tar -xjf /tmp/ncpackage.tar.bz2 -C /tmp/nc
sudo chown -R www-data:www-data /tmp/nc
sudo chmod -R 770 /tmp/nc

# Set up PHP-FPM
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    php-fpm \
    php-intl \
    php-ldap \
    php-imap \
    php-gd \
    php-sqlite3 \
    php-curl \
    php-xml \
    php-zip \
    php-mbstring \
    php-soap \
    php-json \
    php-gmp \
    php-bz2 \
    php-bcmath \
    php-pear;

# Install Nextcloud
sudo -u www-data \
    php -f /tmp/nc/nextcloud/occ \
    maintenance:install \
    --database=sqlite \
    --admin-user=admin \
    --admin-pass=password

# Enable pretty URLS
sudo -u www-data php -f /tmp/nc/nextcloud/occ config:system:set htaccess.RewriteBase --value="/"
sudo -u www-data php -f /tmp/nc/nextcloud/occ maintenance:update:htaccess

# Create file with final prettyurl config
echo "# Retreived from $NC_DOMAIN" > /tmp/htaccess.conf

# Get content of the changed htaccess file and write it to the new htaccess file
sudo sed -e '1,/DO NOT CHANGE ANYTHING ABOVE THIS LINE/d' /tmp/nc/nextcloud/.htaccess >> /tmp/htaccess.conf

# Overwrite changes
cat /tmp/htaccess.conf > ./src/apache/conf/.htaccess
