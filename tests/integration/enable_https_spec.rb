feature "Enabling HTTPS" do
	after(:all) do
		disable_https
	end

	scenario "self-signed" do
		enable_https

		visit "/"
		fill_in "user", with: "admin"
		fill_in "password", with: "admin"
		click_button "Log in"
		expect(page).to have_content /(Recommended|All) files/
	end
end
