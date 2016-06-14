# Snappy Nextcloud

Nextcloud server packaged as a snap. It consists of:

- Nextcloud 9.0.50
- Apache 2.4
- PHP 7
- mysql 5.7
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


### Included CLI utilities

There are a few CLI utilities included:

- `nextcloud.occ`:
    - Nextcloud's `occ` configuration tool. Note that it requires `sudo`.
- `nextcloud.mysql-client`:
    - MySQL client preconfigured to communicate with Nextcloud MySQL server.
      This may be useful in case you need to migrate Nextcloud installations.
      Note that it requires `sudo`.


## Where is my stuff?

- `$SNAP_DATA`:
    - Apache and MySQL logs
    - MySQL database
    - Nextcloud config
    - Any Nextcloud apps installed by the user
- `$SNAP_DATA/../common` (unversioned directory):
    - Nextcloud data
    - Nextcloud logs
