import os
import logging
import shutil
import re
import subprocess

import snapcraft
from snapcraft.plugins import autotools

logger = logging.getLogger(__name__)


class PhpPlugin(autotools.AutotoolsPlugin):

    @classmethod
    def schema(cls):
        schema = super().schema()
        schema['properties']['extensions'] = {
            'type': 'array',
            'minitems': 1,
            'uniqueItems': True,
            'items': {
                'type': 'string'
            },
            'default': [],
        }

        return schema

    def __init__(self, name, options, project):
        super().__init__(name, options, project)

    def build(self):
        super().build()

        for extension in self.options.extensions:
            self.run(['pecl', 'install', extension], cwd=os.path.join(self.installdir, 'bin'))
