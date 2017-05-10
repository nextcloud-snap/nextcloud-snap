# Snappy Nextcloud

Nextcloud server packaged as a snap. It consists of:

- Nextcloud 11.0.3
- Apache 2.4
- PHP 7
- MySQL 5.7
- Redis 3.2
- mDNS for network discovery


## How to install

This Nextcloud snap is available in the store for release series 16 (e.g. Ubuntu
16.04). Install via:

    $ sudo snap install nextcloud


## How to use

After install, assuming you and the device on which it was installed are on the
same network, you should be able to reach the Nextcloud installation by visiting
`<hostname>.local` in your browser. If your hostname is `localhost` or
`localhost.localdomain`, like on an Ubuntu Core device, `nextcloud.local` will
be used instead.

Upon visiting the Nextcloud installation for the first time, you'll be prompted
for an admin username and password. After you provide that information you'll be
logged in and able to create users, install apps, and upload files.

Note that this snap includes a service that runs cron.php every 15 minutes,
which will automatically change the cron admin setting to Cron for you.


### Removable media

Also note that the interface providing the ability to access removable media is
not automatically connected upon install, so if you'd like to use external
storage (or otherwise use a device in `/media` for data), you need to give the
snap permission to access removable media by connecting that interface:

    $ sudo snap connect nextcloud:removable-media


### HTTP/HTTPS port configuration

By default, the snap will listen on port 80. If you enable HTTPS, it will listen
on both 80 and 443, and HTTP traffic will be redirected to HTTPS. But perhaps
you're putting the snap behind a proxy of some kind, in which case you probably
want to change those ports.

If you'd like to change the HTTP port (say, to port 81), run:

    $ sudo snap set nextcloud ports.http=81

To change the HTTPS port (say, to port 444), run:

    $ sudo snap set nextcloud ports.https=444

Note that, assuming HTTPS is enabled, this will cause HTTP traffic to be
redirected to port 444. You can specify both of these simultaneously as well:

    $ sudo snap set nextcloud ports.http=81 ports.https=444


### Included CLI utilities

There are a few CLI utilities included:

- `nextcloud.occ`:
    - Nextcloud's `occ` configuration tool. Note that it requires `sudo`.
- `nextcloud.mysql-client`:
    - MySQL client preconfigured to communicate with Nextcloud MySQL server.
      This may be useful in case you need to migrate Nextcloud installations.
      Note that it requires `sudo`.
- `nextcloud.mysqldump`:
    - Dump Nextcloud database to stdout. You should probaby redirect its output
      to a file. Note that it requires `sudo`.
- `nextcloud.enable-https`:
    - Enable HTTPS via self-signed certificates, Let's Encrypt, or custom
      certificates. HTTP will redirect to HTTPS. Non-custom certificates will
      automatically be kept up-to-date. See `nextcloud.enable-https -h` for more
      information. Note that it requires `sudo`.
- `nextcloud.disable-https`:
    - Disable HTTPS (does not remove certificates). Note that it requires
      `sudo`.
- `nextcloud.manual-install`:
    - Manually install Nextcloud instead of visiting it in your browser. This
      allows you to create the admin user via the CLI. Note that it requires
      `sudo`.


## Where is my stuff?

- `$SNAP_DATA`:
    - Apache, PHP, MySQL, and Redis logs
    - Keys and certificates
    - MySQL database
    - Redis database
    - Nextcloud config
    - Any Nextcloud apps installed by the user
- `$SNAP_COMMON`
    - Nextcloud data
    - Nextcloud logs
