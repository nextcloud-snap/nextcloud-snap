from setuptools import setup, find_packages


setup(
	name='nextcloud',
	packages=find_packages(),
	install_requires=[
		'certbot~=1.20.0',
	],
	entry_points={
		'certbot.plugins': [
			'webroot = certbot_nextcloud_plugin.webroot:Authenticator',
		],
	},
)
