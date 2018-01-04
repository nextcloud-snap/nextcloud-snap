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
                    'source-checksum': {
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

    def __fix_libpath_getDist(self):
        # Because my alternative to the missing "endif" is goto....
        # Get the current distro.
        distCheck_raw = subprocess.check_output("if [ \"`lsb_release -is`\" = \'Ubuntu\' ] ; then echo 1; else echo 0; fi;", shell=True)
        distCheck = int(distCheck_raw.decode('utf-8'))
        return distCheck

    def __fix_libpath_getPath(self, distCheck):
        # Because my alternative to the missing "endif" is goto....
        # Get the current library path. (If needed)
        if distCheck == 1:
            # Ubuntu. We need to set the lib directory to the correct tupple for the system arch.
            libPath_raw = subprocess.check_output("gcc -dumpmachine", shell=True)
            libPath = ('lib/' + libPath_raw.decode('utf-8')).rstrip('\r\n')
            return libPath
        else:
            # The default is to not modifiy anything.
            libPath = ''
            return libPath

    def __fix_libpath_fixFlag(self, flag, libPath, count):
        # Check for the correct flag and fix it if found.
        if "--with-libdir=" in flag:
            # Got a match fix the flag.
            fixed_flag = '--with-libdir=' + libPath
            logger.info('Fixing libdir flag at configflag index ' + str(count) + ' to: \'' + fixed_flag + '\'')
            del self.options.configflags[count]
            self.options.configflags.insert(count, fixed_flag)

    def __fix_libpath_fixFlag_loop(self, libPath):
        # Create a counter.
        count = 0

        # Check for pre-existing flags.
        for flag in self.options.configflags:
            self.__fix_libpath_fixFlag(flag, libPath, count)

            # Increment count.
            count = count + 1

    def __fix_library_path(self):
        # Set up the vars.
        libPath = ''
        distCheck = 0

        # Get the current library path.
        distCheck = self.__fix_libpath_getDist()
        libPath = self.__fix_libpath_getPath(distCheck)

        # Check to see if we need to continue. (We abort if distCheck is zero.)
        if not distCheck == 0:
            logger.info('Modifications to --with-libdir flag may be required.')
            if not libPath == "":
                if self.options.configflags:
                    logger.info('Checking configflags....')

                    # Call loop function.
                    self.__fix_libpath_fixFlag_loop(libPath)
                else: # self.options.configflags
                    logger.info('No configflags defined???')
            else: #not libPath == ""
                logger.info('No libPath defined, cannot fix --with-libdir flag without it. The build may fail.')
        else: # not distCheck == 0
            logger.info('No modifications to --with-libdir flag required.')

    def build(self):
        # Check for a broken libpath.
        self.__fix_library_path()

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
