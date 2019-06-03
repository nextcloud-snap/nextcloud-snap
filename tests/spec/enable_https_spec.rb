feature "Enabling HTTPS" do
	after(:all) do
		disable_https
	end

	scenario "self-signed" do
		enable_https

		visit "/"
		fill_in "User", with: "admin"
		fill_in "Password", with: "admin"
		click_button "Log in"
		expect(page).to have_content "All files"
	end
end
