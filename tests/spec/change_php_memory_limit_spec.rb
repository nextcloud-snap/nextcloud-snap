feature "Change PHP memory limit" do
	scenario "unlimited" do
		`sudo snap set nextcloud php.memory-limit=-1`
		expect($?.to_i).to eq 0
		wait_for_nextcloud

		assert_login

		# Also assert that we can change it back to the default
		`sudo snap set nextcloud php.memory-limit=128M`
		expect($?.to_i).to eq 0
		wait_for_nextcloud

		assert_logged_in
	end

	scenario "bytes" do
		`sudo snap set nextcloud php.memory-limit=536870912`
		expect($?.to_i).to eq 0
		wait_for_nextcloud

		assert_login

		# Also assert that we can change it back to the default
		`sudo snap set nextcloud php.memory-limit=128M`
		expect($?.to_i).to eq 0
		wait_for_nextcloud

		assert_logged_in
	end

	scenario "invalid" do
		# This will print to stderr. Hide it.
		`sudo snap set nextcloud php.memory-limit=invalid 2>&1`
		expect($?.to_i).to_not eq 0
		wait_for_nextcloud

		assert_login
	end

	protected

	def assert_login
		visit "/"
		fill_in "User", with: "admin"
		fill_in "Password", with: "admin"
		click_button "Log in"
		expect(page).to have_content "Documents"
	end

	def assert_logged_in
		visit "/"
		expect(page).to have_content "Documents"
	end
end
