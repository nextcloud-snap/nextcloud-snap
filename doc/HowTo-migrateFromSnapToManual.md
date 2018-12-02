# How to migrate from nextcloud-snap to Nextcloud 

The `nextcloud-snap` is very good.  For some situations it is the perfect solution but there are problems:

1. Little documentation for custom tools

2. Slow and steady release schedule may not work for all clients

3. Some current tools are limited (example: deleting letsencrypt certificates)


If you need to move from `nextcloud-snap` to Nextcloud server here are some notes:



## Install NextCloud

Follow the terrible documentation on installing Nextcloud: 

https://docs.nextcloud.com/server/14/admin_manual/installation/source_installation.html#ubuntu-installation-label

### Suggestions:

#### Some dependencies:

`# apt-get install apache2 mariadb-server libapache2-mod-php php-gd php-json php-mysql php-curl php-mbstring php-intl php-mcrypt php-imagick php-xml php-zip php-fileinfo php-bz2 php-redis php-apcu ffmpeg`

#### To secure the mariaDB installation:

`# mysql_secure_installation`

#### To avoid the /nextcloud folder in your URL

1. Extract nextcloud to `/var/www/nextcloud`

2. Then chmod (example for Debian):

`# chown -R www-data:www-data /var/www/nextcloud`



## Export Database from snap

Run this on the OLD server:

`# nextcloud.mysqldump > my-old-nextcloud.sql`

Copy `my-old-nextcloud.sql` file to the new server (`rsync` or `scp` etc)


## Database on NEW server

#### Allow larger innoDB

`# mysql -u root -p`

```
> SET GLOBAL innodb_file_format=Barracuda;
> SET GLOBAL innodb_file_per_table=ON;
> SET GLOBAL innodb_large_prefix=1;
```

Now logout & login (to get the global values).

#### create the new database:

`> CREATE DATABASE nextcloud;`


## Populate NEW Database

`# mysql -u root -p nextcloud < my-old-nextcloud.sql`


## Move Files to New Server

Run this command from OLD server:

`# rsync -avz --delete /var/snap/nextcloud/common/nextcloud/data/ root@your-new-server:/var/www/nextcloud/data/`


## Migrate SSL Certificates

These instructions assume you are using LetsEncrypt.  The nextcloud-snap letsencrypt tool does not allow you to delete certificates but you can get around that this way.


1. Point your Nextcloud domain to the new server.

2. Install certbot on the new server.

3. Install the certificate with this command:

`# certbot certonly -d nextcloud.yourdomain.com`

You can let the old certificates expire.  Just do nothing.

You can add this line to a cron job as root on the NEW server to automatically update the certificate:

`certbot renew --rsa-key-size 4096 --pre-hook "service apache2 stop" --post-hook "service apache2 start"`


## Apache2 configuration

#### Some modules you will need:

`# a2enmod ssl rewrite env headers mime dir`

#### Sample conf file

This file will redirect all traffic to https using the SSL certificate you created in the step above.

`# vi /etc/apache2/sites-enabled/nextcloud.conf`

```
<VirtualHost *:80>
  DocumentRoot /var/www/nextcloud/
  ServerName  nextcloud.yourdomain.com

<Directory "/var/www/nextcloud/">
  Require all granted
  AllowOverride All
  Options FollowSymLinks MultiViews
</Directory>
 
  RewriteEngine On
  RewriteCond %{HTTPS} off 
  RewriteRule (.*) https://%{SERVER_NAME}/$1 [R,L] 
</VirtualHost>

<VirtualHost *:443>
        SSLEngine on
        SSLCertificateFile /etc/letsencrypt/live/nextcloud.yourdomain.com/fullchain.pem
        SSLCertificateKeyFile /etc/letsencrypt/live/nextcloud.yourdomain.com/privkey.pem
        <Directory /var/www/nextcloud/>
                AllowOverride All 
                Require all granted
                Options FollowSymLinks MultiViews
        </Directory>
        DocumentRoot /var/www/nextcloud/
        ServerName nextcloud.yourdomain.com
</VirtualHost>

```

`# service apache2 restart`

## Done?

I think this was everything I did to make it work (not including many things from the Intallation instructions at https://docs.nextcloud.com/server/14/admin_manual/installation/source_installation.html#ubuntu-installation-label for things like Redis, possibly other dependencies.

What I learned is that the `nextcloud-snap` is more standardized than I thought.  But for some use cases it is not the best solution.  For many other situations it definitely is great.