feature "Logging in" do
	scenario "Logging in with correct credentials" do
		visit "/"
		fill_in "User", with: "admin"
		fill_in "Password", with: "admin"
		click_button "Log in"
		expect(page).to have_content "Recommended files"
	end

	scenario "Logging in with incorrect credentials" do
		visit "/"
		fill_in "User", with: "wronguser"
		fill_in "Password", with: "wrongpassword"
		click_button "Log in"
		expect(page).to have_content /Wrong.*password/
	end
end
