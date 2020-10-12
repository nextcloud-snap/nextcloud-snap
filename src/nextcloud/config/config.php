<?php

$snap_current = getenv('SNAP_CURRENT');
$snap_data_current = getenv('SNAP_DATA_CURRENT');

$CONFIG = array(
/**
 * Use the ``apps_paths`` parameter to set the location of the Apps directory,
 * which should be scanned for available apps, and where user-specific apps
 * should be installed from the Apps store. The ``path`` defines the absolute
 * file system path to the app folder. The key ``url`` defines the HTTP web path
 * to that folder, starting from the Nextcloud web root. The key ``writable``
 * indicates if a web server can write files to that folder.
 */
'apps_paths' => array(
	/**
	 * These are the default apps shipped with Nextcloud. They are read-only.
	 */
	array(
		'path'=> $snap_current.'/htdocs/apps',
		'url' => '/apps',
		'writable' => false,
	),

	/**
	 * This directory is writable, meant for apps installed by the user.
	 */
	array(
		'path'=> $snap_data_current.'/nextcloud/extra-apps',
		'url' => '/extra-apps',
		'writable' => true,
	),
),

/**
 * Database types that are supported for installation.
 *
 * Available:
 * 	- sqlite (SQLite3 - Not in Enterprise Edition)
 * 	- mysql (MySQL)
 * 	- pgsql (PostgreSQL)
 * 	- oci (Oracle - Enterprise Edition Only)
 */
'supportedDatabases' => array(
	'mysql',
),

'memcache.locking' => '\OC\Memcache\Redis',
'memcache.local' => '\OC\Memcache\Redis',
'redis' => array(
    'host' => getenv('REDIS_SOCKET'),
    'port' => 0,
),

'log_type' => 'file',
'logfile' => $snap_data_current.'/logs/nextcloud.log',
'logfilemode' => 0640,
);
