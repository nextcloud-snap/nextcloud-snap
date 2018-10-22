feature "Import and export data" do
	scenario "export then import" do
		`sudo nextcloud.export`
		expect($?.to_i).to eq 0

		backups = Dir.glob("/var/snap/nextcloud/common/backups/*")
		expect(backups.length).to eq 1
		backup = backups[0]

		# Move backup out of the snap's dirs
		moved_backup = File.join(Dir.tmpdir, File.basename(backup))
		`sudo mv "#{backup}" "#{moved_backup}"`

		snap_paths = Dir.glob("/var/lib/snapd/snaps/nextcloud_*.snap")
		expect(snap_paths.length).to eq 1
		snap_path = snap_paths[0]

		# Create a backup of the snap that's currently installed
		moved_snap_path = File.join(Dir.tmpdir, File.basename(snap_path))
		`sudo cp "#{snap_path}" "#{moved_snap_path}"`

		# Now completely uninstall/reinstall the snap
		`sudo snap remove nextcloud`
		`sudo snap install "#{moved_snap_path}" --dangerous`

		# Now restore the backup, and verify we can still login like normal
		`sudo mkdir -p "$(dirname "#{backup}")"`
		`sudo mv "#{moved_backup}" "#{backup}"`
		`sudo nextcloud.import "#{backup}"`
		assert_loginable
	end

	protected

	def assert_loginable
		visit "/"
		fill_in "User", with: "admin"
		fill_in "Password", with: "admin"
		click_button "Log in"
		expect(page).to have_content "Documents"
	end
end
