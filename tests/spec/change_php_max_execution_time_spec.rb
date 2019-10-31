feature "Change PHP max execution time" do
	after(:all) do
		set_config "php.max-execution-time": 3600
		wait_for_nextcloud
	end

	scenario "unlimited" do
		set_config "php.max-execution-time": -1
		wait_for_nextcloud

		assert_login

		# Also assert that we can change it back to the default
		set_config "php.max-execution-time": 3600
		wait_for_nextcloud

		assert_logged_in
	end

	scenario "invalid" do
		# This will print to stderr. Hide it.
		`sudo snap set nextcloud php.max-execution-time=invalid 2>&1`
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
		expect(page).to have_content "All files"
	end

	def assert_logged_in
		visit "/"
		expect(page).to have_content "All files"
	end
end
