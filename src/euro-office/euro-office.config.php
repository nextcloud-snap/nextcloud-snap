<?php

// Managed by the snap: exists only while the euro-office plug is connected.
// Anything set in the admin settings takes precedence over these.
$connection = json_decode((string)@file_get_contents(getenv('SNAP_CURRENT').'/euro-office/connection.json'), true);

$CONFIG = array();

if (is_array($connection)) {
	$CONFIG['eurooffice'] = array(
		'DocumentServerUrl' => '/euro-office/',
		'DocumentServerInternalUrl' => $connection['url'],
		'StorageUrl' => 'http://localhost:8481/',
		'jwt_secret' => $connection['jwt_secret'],
	);
}
