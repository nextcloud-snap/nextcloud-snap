import os
import logging
import shutil
import re
import subprocess

import snapcraft
from snapcraft.plugins import autotools

logger = logging.getLogger(__name__)


def _populate_options(options, properties, schema):
    schema_properties = schema.get('properties', {})
    for key in schema_properties:
        attr_name = key.replace('-', '_')
        default_value = schema_properties[key].get('default')
        attr_value = properties.get(key, default_value)
        setattr(options, attr_name, attr_value)

class PhpPlugin(autotools.AutotoolsPlugin):

    @classmethod
    def schema(cls):
        schema = super().schema()
        schema['properties']['extensions'] = {
            'type': 'array',
            'minitems': 1,
            'uniqueItems': True,
            'default': [],
            'items': {
                'type': 'object',
                'properties': {
                    'source': {
                        'type': 'string'
                    },
                    'source-type': {
                        'type': 'string'
                    },
                    'source-branch': {
                        'type': 'string'
                    },
                    'source-subdir': {
                        'type': 'string'
                    },
                    'configflags': {
                        'type': 'array',
                        'minitems': 1,
                        'uniqueItems': True,
                        'items': {
                            'type': 'string',
                        },
                        'default': [],
                    }
                }
            }
        }

        return schema

    def __init__(self, name, options, project):
        super().__init__(name, options, project)

        self.extensions_directory = os.path.join(self.partdir, 'extensions')

        class Options():
            pass

        self.extensions = []

        schema = self.schema()['properties']['extensions']['items']

        for index, extension in enumerate(self.options.extensions):
            options = Options()
            _populate_options(options, extension, schema)
            options.extension_directory = os.path.join(
                self.extensions_directory, 'extension-{}'.format(index))
            self.extensions.append(options)

    def pull(self):
        super().pull()

        # Now pull extensions
        if self.extensions:
            logger.info('Pulling PHP extensions...')

        for extension in self.extensions:
            extension_source_directory = os.path.join(
                extension.extension_directory, 'src')
            os.makedirs(extension_source_directory)
            snapcraft.sources.get(extension_source_directory, None, extension)

    def clean_pull(self):
        super().clean_pull()

        if os.path.exists(self.extensions_directory):
            shutil.rmtree(self.extensions_directory)

    def build(self):
        super().build()

        if self.extensions:
            logger.info('Building PHP extensions...')

        for extension in self.extensions:
            extension_source_directory = os.path.join(
                extension.extension_directory, 'src')
            extension_build_directory = os.path.join(
                extension.extension_directory, 'build')

            if os.path.exists(extension_build_directory):
                shutil.rmtree(extension_build_directory)

            shutil.copytree(extension_source_directory, extension_build_directory)

            self.run(['{}/phpize'.format(os.path.join(self.installdir, 'bin'))],
                     cwd=extension_build_directory)
            self.run(['./configure'] + extension.configflags,
                     cwd=extension_build_directory)
            self.run(['make', '-j{}'.format(
                self.project.parallel_build_count)],
                cwd=extension_build_directory)
            self.run(['make', 'install'], cwd=extension_build_directory)
