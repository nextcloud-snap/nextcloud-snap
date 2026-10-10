feature "Change APC shm size" do
        after(:all) do
                set_config "php.apc-shm-size": "32M"
                wait_for_nextcloud
        end

        scenario "shorthand" do
                set_config "php.apc-shm-size": "256M"
                wait_for_nextcloud

                assert_login

                # Also assert that we can change it back to the default
                set_config "php.apc-shm-size": "32M"
                wait_for_nextcloud

                assert_logged_in
        end

        scenario "bytes" do
                set_config "php.apc-shm-size": 268435456
                wait_for_nextcloud

                assert_login

                # Also assert that we can change it back to the default
                set_config "php.apc-shm-size": "32M"
                wait_for_nextcloud

                assert_logged_in
        end

        scenario "invalid" do
                # This will print to stderr. Hide it.
                `sudo snap set nextcloud php.apc-shm-size=invalid 2>&1`
                expect($?.to_i).to_not eq 0
                wait_for_nextcloud

                assert_login
        end

        protected

        def assert_login
                visit "/"
                fill_in "user", with: "admin"
                fill_in "password", with: "admin"
                click_button "Log in"
                sleep 3
                expect(page).to have_content /(Recommended|All) files/
        end

        def assert_logged_in
                visit "/"
                expect(page).to have_content /(Recommended|All) files/
        end
end