feature "Logging in" do
	scenario "Logging in with correct credentials" do
		visit "/"
		fill_in "user", with: "admin"
		fill_in "password", with: "admin"
		click_button "Log in"
		expect(page).to have_content /(Recommended|All) files/
	end

	scenario "Logging in with incorrect credentials" do
		visit "/"
		fill_in "user", with: "wronguser"
		fill_in "password", with: "wrongpassword"
		click_button "Log in"
		expect(page).to have_content /Wrong.*password/
	end
end
