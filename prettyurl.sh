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

# Get content of the changed htaccess file and store it in a Variable called updateHtaccess
updateHtaccess="$(sudo sed -e '1,/DO NOT CHANGE ANYTHING ABOVE THIS LINE/d' /tmp/nc/nextcloud/.htaccess)"

# Create file with final prettyurl config
echo "# Retreived from $NC_DOMAIN" >> /tmp/htaccess.conf
echo "$updateHtaccess" >> /tmp/htaccess.conf

# Overwrite Webroot config
sed -i 's|ErrorDocument 403.*|ErrorDocument 403 \${WEBROOT}/|' /tmp/htaccess.conf
sed -i 's|ErrorDocument 404.*|ErrorDocument 404 \${WEBROOT}/|' /tmp/htaccess.conf

# Overwrite Rewritebase config
sed -i 's|RewriteBase.*|RewriteBase \${REWRITEBASE}|' /tmp/htaccess.conf

# Overwrite changes
cat /tmp/htaccess.conf > ./src/apache/conf/.htaccess
