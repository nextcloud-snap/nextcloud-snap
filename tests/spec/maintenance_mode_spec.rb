feature "Maintenance mode" do
    # Regression test for #486.
    scenario "enable/disable" do
        # First, verify that maintenance mode is not active
        visit "/"
        expect(page).not_to have_content('maintenance mode')

        # Enable maintenance mode
		`sudo nextcloud.occ maintenance:mode --on`
        expect($?.to_i).to eq 0

        # Now verify that maintenance mode is active
        visit "/"
        expect(page).to have_content('maintenance mode')

        # Now disable maintenance mode
        `sudo nextcloud.occ maintenance:mode --off`
        expect($?.to_i).to eq 0

        # Finally, verify that maintenance mode is not active again
        visit "/"
        expect(page).not_to have_content('maintenance mode')
	end
end
