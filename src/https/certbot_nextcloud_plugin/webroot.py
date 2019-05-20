"""Nextcloud Webroot plugin."""
import argparse
import collections
import errno
import json
import logging
import os

import six
import zope.component
import zope.interface

from acme import challenges

from certbot import cli
from certbot import errors
from certbot import interfaces
from certbot.display import util as display_util
from certbot.plugins import common


logger = logging.getLogger(__name__)


@zope.interface.implementer(interfaces.IAuthenticator)
@zope.interface.provider(interfaces.IPluginFactory)
class Authenticator(common.Plugin):
    """Nextcloud Webroot Authenticator."""

    description = "Place files in webroot directory without running chown"

    MORE_INFO = """\
Authenticator plugin that performs http-01 challenge by saving
necessary validation resources to appropriate paths on the file
system. It expects that there is some other HTTP server configured
to serve all files under specified web root ({0})."""

    def more_info(self):  # pylint: disable=missing-docstring,no-self-use
        return self.MORE_INFO.format(self.conf("path"))

    @classmethod
    def add_parser_arguments(cls, add):
        add("path", type=str, default='', help="public_html / webroot path")
        add("map", default={}, help="Not used. Left for backward compatibility.")

    def get_chall_pref(self, domain):  # pragma: no cover
        # pylint: disable=missing-docstring,no-self-use,unused-argument
        return [challenges.HTTP01]

    def __init__(self, *args, **kwargs):
        super(Authenticator, self).__init__(*args, **kwargs)
        self.full_roots = {}
        self.performed = collections.defaultdict(set)

    def prepare(self):  # pylint: disable=missing-docstring
        pass

    def perform(self, achalls):  # pylint: disable=missing-docstring
        webroot_path = self.conf("path")
        if not webroot_path:
            raise errors.PluginError("Missing path")

        # The previous version had this as an array, but it gets loaded as
        # a string. Just strip off the braces and quotes.
        setattr(self.config, self.dest("path"), webroot_path.strip("[]'"))
        logger.info("Using the webroot path %s for all domains.",
                    self.conf("path"))

        self._create_challenge_dirs(achalls)

        return [self._perform_single(achall) for achall in achalls]

    def _create_challenge_dirs(self, achalls):
        for achall in achalls:
            self.full_roots[achall.domain] = os.path.join(
                self.conf("path"), challenges.HTTP01.URI_ROOT_PATH)

            logger.debug("Creating root challenges validation dir at %s",
                         self.conf("path"))

            # Change the permissions to be writable (GH #1389)
            # Umask is used instead of chmod to ensure the client can also
            # run as non-root (GH #1795)
            old_umask = os.umask(0o022)

            try:
                # This is coupled with the "umask" call above because
                # os.makedirs's "mode" parameter may not always work:
                # https://stackoverflow.com/questions/5231901/permission-problems-when-creating-a-dir-with-os-makedirs-python
                os.makedirs(self.full_roots[achall.domain], 0o0755)

            except OSError as exception:
                if exception.errno != errno.EEXIST:
                    raise errors.PluginError(
                        "Couldn't create root for {0} http-01 "
                        "challenge responses: {1}", achall.domain, exception)
            finally:
                os.umask(old_umask)

    def _get_validation_path(self, root_path, achall):
        return os.path.join(root_path, achall.chall.encode("token"))

    def _perform_single(self, achall):
        response, validation = achall.response_and_validation()

        root_path = self.full_roots[achall.domain]
        validation_path = self._get_validation_path(root_path, achall)
        logger.debug("Attempting to save validation to %s", validation_path)

        # Change permissions to be world-readable, owner-writable (GH #1795)
        old_umask = os.umask(0o022)

        try:
            with open(validation_path, "wb") as validation_file:
                validation_file.write(validation.encode())
        finally:
            os.umask(old_umask)

        self.performed[root_path].add(achall)

        return response

    def cleanup(self, achalls):  # pylint: disable=missing-docstring
        for achall in achalls:
            root_path = self.full_roots.get(achall.domain, None)
            if root_path is not None:
                validation_path = self._get_validation_path(root_path, achall)
                logger.debug("Removing %s", validation_path)
                os.remove(validation_path)
                self.performed[root_path].remove(achall)

        for root_path, achalls in six.iteritems(self.performed):
            if not achalls:
                try:
                    os.rmdir(root_path)
                    logger.debug("All challenges cleaned up, removing %s",
                                 root_path)
                except OSError as exc:
                    logger.info(
                        "Unable to clean up challenge directory %s", root_path)
                    logger.debug("Error was: %s", exc)
