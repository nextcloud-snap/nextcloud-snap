feature "Change OPCache Memory Consumption Value" do
	after(:all) do
		set_config "php.opcache_memory_consumption": "128M"
		wait_for_nextcloud
	end

	scenario "unlimited" do
		set_config "php.php.opcache_memory_consumption": -1
		wait_for_nextcloud

		assert_login

		# Also assert that we can change it back to the default
		set_config "php.opcache_memory_consumption": "128M"
		wait_for_nextcloud

		assert_logged_in
	end

	scenario "bytes" do
		set_config "php.opcache_memory_consumption": 134217728
		wait_for_nextcloud

		assert_login

		# Also assert that we can change it back to the default
		set_config "php.opcache_memory_consumption": "128M"
		wait_for_nextcloud

		assert_logged_in
	end

	scenario "invalid" do
		# This will print to stderr. Hide it.
		`sudo snap set nextcloud php.opcache_memory_consumption=invalid 2>&1`
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
