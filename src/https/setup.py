from setuptools import setup, find_packages


setup(
	name='nextcloud',
	packages=find_packages(),
	install_requires=[
		'certbot',
		'zope.interface',
	],
	entry_points={
		'certbot.plugins': [
			'webroot = certbot_nextcloud_plugin.webroot:Authenticator',
		],
	},
)
