import os
import logging
import shutil
import re
import subprocess

import snapcraft

logger = logging.getLogger(__name__)


def _search_and_replace(directory, search_pattern, replacement):
    for root, directories, files in os.walk(directory):
        for file_name in files:
            _search_and_replace_contents(os.path.join(root, file_name),
                                         search_pattern, replacement)

def _search_and_replace_contents(file_path, search_pattern, replacement):
    try:
        with open(file_path, 'r+') as f:
            try:
                original = f.read()
            except UnicodeDecodeError:
                # This was probably a binary file. Skip it.
                return

            replaced = search_pattern.sub(replacement, original)
            if replaced != original:
                f.seek(0)
                f.truncate()
                f.write(replaced)
    except PermissionError:
        logger.warning('Unable to open {!r} for writing-- skipping...'.format(
            file_path))

def _populate_options(options, properties, schema):
    schema_properties = schema.get('properties', {})
    for key in schema_properties:
        attr_name = key.replace('-', '_')
        default_value = schema_properties[key].get('default')
        attr_value = properties.get(key, default_value)
        setattr(options, attr_name, attr_value)

class ApachePlugin(snapcraft.BasePlugin):

    @classmethod
    def schema(cls):
        schema = super().schema()
        schema['properties']['modules'] = {
            'type': 'array',
            'minitems': 1,
            'uniqueItems': True,
            'items': {
                'type': 'string'
            },
        }
        schema['properties']['third-party-modules'] = {
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
        schema['properties']['startup-script'] = {
            'type': 'string',
            'default': '',
        }
        schema['properties']['extra-configuration'] = {
            'type': 'string',
            'default': '',
        }

        schema['required'].append('modules')

        return schema

    def __init__(self, name, options, project):
        super().__init__(name, options, project)

        self.build_packages.extend(
            ['pkg-config', 'libapr1-dev', 'libaprutil1-dev', 'libpcre3-dev',
             'libssl-dev'])

        self.apache_directory = os.path.join(self.partdir, 'apache')
        self.third_party_modules_directory = os.path.join(
            self.partdir, 'third-party-modules')
        self.startup_file_path = os.path.join('bin', 'startup_script')
        self.extra_configuration_file_path = os.path.join(
            'conf', 'extra_configuration')

        class Options():
            pass

        self.third_party_modules = []

        schema = self.schema()['properties']['third-party-modules']['items']

        for index, module in enumerate(self.options.third_party_modules):
            options = Options()
            _populate_options(options, module, schema)
            options.module_directory = os.path.join(
                self.third_party_modules_directory, 'module-{}'.format(index))
            self.third_party_modules.append(options)

    def pull(self):
        super().pull()

        if self.options.startup_script and not os.path.isfile(self.options.startup_script):
            raise RuntimeError(
                'startup-script file "{}" doesn\'t exist'.format(
                    self.options.startup_script))

        if self.options.extra_configuration and not os.path.isfile(self.options.extra_configuration):
            raise RuntimeError(
                'extra-configuration file "{}" doesn\'t exist'.format(
                    self.options.extra_configuration))

        apache_source_directory = os.path.join(self.apache_directory, 'src')
        apache_sources = snapcraft.sources.Tar('http://ftp.wayne.edu/apache/httpd/httpd-2.4.20.tar.gz', apache_source_directory)

        os.makedirs(apache_source_directory)

        logger.info('Downloading Apache sources...')
        apache_sources.pull()

        self._pull_third_party_modules()

    def _pull_third_party_modules(self):
        logger.info('Pulling third-party modules...')
        for module in self.third_party_modules:
            module_source_directory = os.path.join(
                module.module_directory, 'src')
            os.makedirs(module_source_directory)
            snapcraft.sources.get(module_source_directory, None, module)

    def clean_pull(self):
        super().clean_pull()

        if os.path.exists(self.apache_directory):
            shutil.rmtree(self.apache_directory)

        if os.path.exists(self.third_party_modules_directory):
            shutil.rmtree(self.third_party_modules_directory)

    def run(self, cmd, cwd=None, **kwargs):
        env = os.environ.copy()
        env['CFLAGS']='-O2'

        super().run(cmd, cwd=cwd, env=env, **kwargs)

    def build(self):
        super().build()

        apache_source_directory = os.path.join(self.apache_directory, 'src')
        apache_build_directory = os.path.join(self.apache_directory, 'build')
        if os.path.exists(apache_build_directory):
            shutil.rmtree(apache_build_directory)

        shutil.copytree(apache_source_directory, apache_build_directory)

        subprocess.check_call("./configure --prefix={} --enable-modules=none --enable-mods-shared='{}' ENABLED_DSO_MODULES='{}'".format(self.installdir, ' '.join(self.options.modules), ','.join(self.options.modules)),
                              cwd=apache_build_directory, shell=True)

        self.run(
            ['make', '-j{}'.format(
                self.project.parallel_build_count)],
            cwd=apache_build_directory)
        self.run(['make', 'install'], cwd=apache_build_directory)

        self._build_third_party_modules()

        # Blow away the htdocs shipped with Apache, and copy in the
        # user-provided one.
        htdocs = os.path.join(self.installdir, 'htdocs')
        shutil.rmtree(htdocs)
        shutil.copytree(self.builddir, htdocs)

        # Copy startup script, if provided
        if self.options.startup_script:

            shutil.copyfile(self.options.startup_script,
                            os.path.join(self.installdir,
                                         self.startup_file_path))

        # Copy extra configuration file, if provided
        if self.options.extra_configuration:
            shutil.copyfile(self.options.extra_configuration,
                            os.path.join(self.installdir,
                                         self.extra_configuration_file_path))

        self._fixup_apachectl()

        # Crawl through the entire install directory, making sure the instances
        # of the installation prefix are replaced with $SNAP.
        _search_and_replace(self.installdir, re.compile(self.installdir),
                            '${SNAP}')

        # Put the Apache logs in $SNAP_DATA/apache/
        self._configure_logging_directory('${SNAP_DATA}/apache/logs')

        self._disable_running_as_user_or_group()
        self._set_mutex_type()

        self._configure_httpd_conf()

        self._configure_startup_procedure()

    def _build_third_party_modules(self):
        logger.info('Building third-party modules...')
        for module in self.third_party_modules:
            module_source_directory = os.path.join(
                module.module_directory, 'src')
            module_build_directory = os.path.join(
                module.module_directory, 'build')

            if os.path.exists(module_build_directory):
                shutil.rmtree(module_build_directory)

            shutil.copytree(module_source_directory, module_build_directory)

            configure_command = [
                './configure', '--prefix=' + self.installdir,
                '--with-apxs2={}/bin/apxs'.format(self.installdir),
                '--disable-rpath']

            self.run(configure_command + module.configflags,
                     cwd=module_build_directory)
            self.run(['make', '-j{}'.format(
                self.project.parallel_build_count)],
                cwd=module_build_directory)
            self.run(['make', 'install'], cwd=module_build_directory)

    def _configure_startup_procedure(self):
        # Setup startup script (piggybacking on envvars)
        with open(os.path.join(self.installdir, 'bin', 'envvars'), 'w') as f:
            f.write('# Make sure log directory exists\n')
            f.write('mkdir -p -m 750 ${SNAP_DATA}/apache\n')
            f.write('mkdir -p -m 750 ${SNAP_DATA}/apache/logs')

            if self.options.startup_script:
                f.write('\n. ${{SNAP}}/{}'.format(self.startup_file_path))

    def _fixup_apachectl(self):
        # Make sure apachectl doesn't use single quotes, and make sure it runs
        # out of $SNAP
        _search_and_replace_contents(
            os.path.join(self.installdir, 'bin', 'apachectl'),
            re.compile(r'HTTPD=.*bin/httpd.*'),
            'HTTPD="${SNAP}/bin/httpd -d ${SNAP}"')

    def _configure_logging_directory(self, log_directory):
        _search_and_replace_contents(
            os.path.join(self.installdir, 'conf', 'httpd.conf'),
            re.compile(r'CustomLog.*'),
            'CustomLog "{}/access_log" common'.format(log_directory))
        _search_and_replace_contents(
            os.path.join(self.installdir, 'conf', 'httpd.conf'),
            re.compile(r'ErrorLog.*'),
            'ErrorLog "{}/error_log"'.format(log_directory))

    def _disable_running_as_user_or_group(self):
        # Don't try to run under a dedicated user/group
        _search_and_replace_contents(
            os.path.join(self.installdir, 'conf', 'httpd.conf'),
            re.compile(r'(User|Group)'), r'# \1')

    def _set_mutex_type(self):
        # Using pthread here, since Apache tries to chown the file-based mutex
        # which isn't allowed in Snappy, and Ubuntu supports robust pthread
        # mutexes that can be recovered if the child process terminates
        # abnormally.
        _search_and_replace_contents(
            os.path.join(self.installdir, 'conf', 'httpd.conf'),
            re.compile(r'# Mutex default:logs'), r'Mutex pthread')

    def _configure_httpd_conf(self):
        with open(os.path.join(self.installdir, 'conf', 'httpd.conf'), 'a') as f:
            # Make sure the pidfile is in a writeable location
            f.write('\nPidFile "${SNAP_DATA}/apache/httpd.pid"')

            # Include extra configuration (if provided)
            if self.options.extra_configuration:
                f.write('\nInclude ${{SNAP}}/{}'.format(
                    self.extra_configuration_file_path))
