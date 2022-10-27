feature "Change OPCache Interned Strings Buffer Value" do
	after(:all) do
		set_config "php.interned_strings_buffer": "8"
		wait_for_nextcloud
	end

	scenario "bytes" do
		set_config "php.interned_strings_buffer": 134217728
		wait_for_nextcloud

		assert_login

		# Also assert that we can change it back to the default
		set_config "php.interned_strings_buffer": "8"
		wait_for_nextcloud

		assert_logged_in
	end

	scenario "invalid" do
		# This will print to stderr. Hide it.
		`sudo snap set nextcloud php.interned_strings_buffer=invalid 2>&1`
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
		expect(page).to have_content /(Recommended|All) files/
	end

	def assert_logged_in
		visit "/"
		expect(page).to have_content /(Recommended|All) files/
	end
end
