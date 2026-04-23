#!/bin/sh
# 
# The custom nextcloud plugin for certbot was replaced by the official 
# webroot plugin in Version 15.0.8snap2. This script should migrate
# existing installations to use the webroot plugin.

set -e

# shellcheck source=src/https/utilities/https-utilities
. "$SNAP/utilities/https-utilities"

printf "Checking if the certbot plugin needs to be migrated... "

if ! certificates_are_active; then
    echo "no (no HTTPS certificates are active)"
    exit
fi

if self_signed_certificates_are_active || custom_certificates_are_active; then
    echo "Not using certbot certificates, so no migration is needed."
    exit
fi

certdir="$(get_most_recent_certificate_directory)"
RENEWAL_CONFIG_FILE="$SNAP_CURRENT/certs/certbot/renewal/$certdir.conf"

if [ ! -f "$RENEWAL_CONFIG_FILE" ]; then
    echo "no (renewal config file not found)"
    exit 1
fi

if grep -q "authenticator = nextcloud:webroot" "$RENEWAL_CONFIG_FILE"; then
    echo "yes"
else
    echo "no"
    exit 0
fi

# Extract the domains from the certificate
AWK_CMD="/^[[:space:]]*X509v3 Subject Alternative Name:/ {
    capture=1
    next
}

/^[[:space:]]*X509v3/ {
    if (capture) exit
}

capture {
    print
}"

domains=$(openssl x509 -noout -text -in "$CERTBOT_LIVE_DIRECTORY/cert.pem" | mawk "$AWK_CMD" | sed -e 's/^[[:space:]]*//g' | tr -d "," | sed -e 's/DNS://g')
echo "Found domains to be migrated: $domains"

# Collect all parameters to be used with certbot.
extra_params=""
dry_run=n

# Check the current ACME server
acme_server=$(grep -E "^server\s*=\s*" "$RENEWAL_CONFIG_FILE" | sed -e 's/^[[:space:]]*server\s*=\s*//g')
if [ "$acme_server" = "https://acme-v02.api.letsencrypt.org/directory" ]; then
    # Default (productive) ACME server, so nothing is needed
    :
elif [ "$acme_server" = "https://acme-staging-v02.api.letsencrypt.org/directory" ]; then
    # Staging ACME server, so we need to add the --staging flag to the certbot command
    extra_params="--staging"
    dry_run=y
else
    echo "error: unrecognized ACME server: $acme_server" >&2
    exit 1
fi

for domain in $domains; do
    extra_params="$extra_params -d $domain"
done

printf "Testing if certificates can be obtained with the webroot plugin... "

# Building CLI commands, so we don't WANT to quote some of these (they need
# to be separated by whitespace): disable the check
# shellcheck disable=SC2086
if output="$(run_certbot_certonly $extra_params --staging --dry-run 2>&1)"; then
    echo "success"
else
    echo "failed!"
    echo "error running certbot:" >&2
    echo "" >&2
    echo "$output" >&2
    exit 1
fi

if [ "$dry_run" = "y" ]; then
    extra_params="$extra_params --staging"
fi

# Moving the legacy plugin to a temporary location.
mv "$SNAP_CURRENT/certs/certbot" "$SNAP_CURRENT/certs/certbot.legacy"

printf "Migrating certbot configuration to use the webroot plugin... "

# Building CLI commands, so we don't WANT to quote some of these (they need
# to be separated by whitespace): disable the check
# shellcheck disable=SC2086
if output="$(run_certbot_certonly $extra_params 2>&1)"; then
    echo "success"
else
    echo "failed!"
    echo "error running certbot:" >&2
    echo "" >&2
    echo "$output" >&2

    echo "Restoring legacy certbot configuration."
    rm -rf "$SNAP_CURRENT/certs/certbot"
    mv "$SNAP_CURRENT/certs/certbot.legacy" "$SNAP_CURRENT/certs/certbot"

    exit 1
fi

echo "Removing legacy certbot configuration."
rm -rf "$SNAP_CURRENT/certs/certbot.legacy"

activate_certbot_certificate
