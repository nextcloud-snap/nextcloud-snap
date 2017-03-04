<?php

$snap_name = getenv('SNAP_NAME');

$data_path = '/var/snap/'.$snap_name.'/current';
$common_data_path = '/var/snap/'.$snap_name.'/common';

$database_password = trim(file_get_contents($data_path . '/mysql/nextcloud_password'));

$AUTOCONFIG = array(
'directory' => $common_data_path.'/nextcloud/data',

'dbtype' => 'mysql',

'dbhost' => 'localhost:'.getenv('MYSQL_SOCKET'),

'dbname' => 'nextcloud',

'dbuser' => 'nextcloud',

'dbpass' => $database_password,
);
