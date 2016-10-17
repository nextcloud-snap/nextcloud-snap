# Snappy Nextcloud

Nextcloud server packaged as a snap. It consists of:

- Nextcloud 10.0.1
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

Note that this snap includes a service that runs cron.php every 15 minutes, but
Nextcloud doesn't currently expose the cron admin setting to autoconfig, so
there's no way for the snap to change the setting from Ajax to Cron for you.
You must do that manually in the admin interface if you want to take advantage
of the performance improvements.


### Included CLI utilities

There are a few CLI utilities included:

- `nextcloud.occ`:
    - Nextcloud's `occ` configuration tool. Note that it requires `sudo`.
- `nextcloud.mysql-client`:
    - MySQL client preconfigured to communicate with Nextcloud MySQL server.
      This may be useful in case you need to migrate Nextcloud installations.
      Note that it requires `sudo`.
- `nextcloud.enable-https`:
    - Enable HTTPS, either via self-signed certificates or via Let's Encrypt.
      HTTP will redirect to HTTPS. The certificates will automatically be kept
      up-to-date. See `nextcloud.enable-https -h` for more information.
- `nextcloud.disable-https`:
    - Disable HTTPS (does not remove certificates).


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
