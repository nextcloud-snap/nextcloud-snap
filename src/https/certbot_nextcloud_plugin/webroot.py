"""Nextcloud Webroot plugin."""

from importlib import import_module

AUTHENTICATOR_PACKAGES = [
    'certbot._internal.plugins.webroot',
    'certbot.plugins.webroot'
]


Authenticator = None

for authenticator_package in AUTHENTICATOR_PACKAGES:
    try:
        Authenticator = getattr(
            import_module(authenticator_package), 'Authenticator'
        )
        break
    except (AttributeError, ModuleNotFoundError):
        continue

if Authenticator is None:
    raise ModuleNotFoundError(
        "Could not find certbot webroot Authenticator module, looked for name"
        f" 'Authenticator' in packages {AUTHENTICATOR_PACKAGES}."
    )
