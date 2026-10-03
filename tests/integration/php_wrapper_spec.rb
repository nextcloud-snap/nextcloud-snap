feature "PHP" do
  # Nextcloud's app_api deploys ExApps by spawning PHP without specifying a
  # configuration file (proc_open('php console.php ...')). The snap's bin/php
  # is a wrapper that always loads the snap's php.ini, so that the extensions
  # bundled in the snap (redis, apcu, ...) are available in that scenario,
  # too. See #3211.
  scenario "loads the snap's php.ini when invoked without one" do
    modules = `sudo snap run --shell nextcloud.occ -c 'php --modules'`
    expect($?.to_i).to eq 0

    # These extensions are only loaded via the snap's php.ini
    expect(modules).to include("redis")
    expect(modules).to include("apcu")
  end
end
