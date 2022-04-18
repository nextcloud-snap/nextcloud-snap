import subprocess
import snapcraft.plugins.v1


class ApachePlugin(snapcraft.plugins.v1.PluginV1):

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

        schema['properties']['mpm'] = {
            'type': 'string',
            'default': 'event',
        }

        schema['required'] = ['modules']

        return schema

    @classmethod
    def get_build_properties(cls):
        # Inform Snapcraft of the properties associated with building. If these
        # change in the YAML Snapcraft will consider the build step dirty.
        return super().get_build_properties() + ["modules", "mpm"]

    def __init__(self, name, options, project):
        super().__init__(name, options, project)

        self.build_packages.extend(
            ['pkg-config', 'libapr1-dev', 'libaprutil1-dev', 'libpcre2-dev',
             'libssl-dev'])
        self.stage_packages.extend(['libapr1', 'libaprutil1', 'libpcre2-8-0'])

    def build(self):
        super().build()

        subprocess.check_call(
            "./configure --prefix={} --with-mpm={} --enable-modules=none --enable-mods-static='{}'".format(
                self.installdir, self.options.mpm,
                ' '.join(self.options.modules)),
            cwd=self.builddir, shell=True)

        self.run(
            ['make', '-j{}'.format(
                self.project.parallel_build_count)],
            cwd=self.builddir)
        self.run(['make', 'install'], cwd=self.builddir)
