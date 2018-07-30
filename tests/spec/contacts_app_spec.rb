feature "Testing contacts app" do
	before :each do
		login
		install_contacts_app
	end

	after :each do
		uninstall_contacts_app
	end

	scenario "add and remove contact" do
		visit_contacts_app

		expect(page).to have_content "No contacts in here"

		# Actually create a new contact (the newline is the enter key)
		click_button "New contact"
		fill_in "details-fullName", with: "Test Contact\n"

		# Wait for the ajax request to go through
		expect(page).to have_selector :xpath, "//div[contains(@class, 'app-content-list')]//div[contains(., 'Test Contact')]", wait: 10

		# Now navigate back to the contacts app again to ensure the contact
		# was actually saved
		visit "/"
		visit_contacts_app
		expect(page).to have_content "Test Contact", wait: 10

		# Finally, delete the contact
		actions = find("#details-actions")
		actions.find(:xpath, ".//div[contains(@class, 'openMenuButton')]").click

		expect(page).to have_content "Delete"
		actions.find(:xpath, ".//a[(@class='icon-delete')]").click
		expect(page).not_to have_content "Test Contact", wait: 10
	end

	protected

	def login
		visit "/"
		fill_in "User", with: "admin"
		fill_in "Password", with: "admin"
		click_button "Log in"
		expect(page).to have_content "Documents"
	end

	def install_contacts_app
		# Go through the user flow to install the contacts app
		find("div#settings").click
		expect(page).to have_content "Apps", wait: 10
		click_link "Apps"

		expect(page).to have_content "Organization", wait: 10
		click_link "Organization"

		expect(page).to have_content "Contacts", wait: 10
		within "#app-contacts" do
			click_button "Enable"
		end

		assert_contacts_installed
	end

	def uninstall_contacts_app
		# Go through the user flow to uninstall the contacts app
		find("#settings").click
		expect(page).to have_content "Apps", wait: 10
		click_link "Apps"

		expect(page).to have_content "Organization", wait: 10
		click_link "Organization"

		expect(page).to have_content "Contacts", wait: 10
		within "#app-contacts" do
			click_button "Disable"
		end

		assert_contacts_not_installed
	end

	def assert_contacts_installed
		expect(page).to have_selector :xpath, "//div[@id='header']//a[contains(@href, 'contacts')]", wait: 10
	end

	def assert_contacts_not_installed
		expect(page).not_to have_selector :xpath, "//div[@id='header']//a[contains(@href, 'contacts')]", wait: 10
	end

	def visit_contacts_app
		# Click the contacts app icon
		find(:xpath, "//div[@id='header']//a[contains(@href, 'contacts')]").click
		expect(page).to have_content "New contact"
	end
end
