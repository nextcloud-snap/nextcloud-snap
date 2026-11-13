feature "Apache timing log" do
        LOG = "/var/snap/nextcloud/current/logs/apache_timing.log"

        after(:all) do
                set_config mode: "production"
                wait_for_nextcloud
        end

        scenario "is disabled in production mode" do
                set_config mode: "production"
                wait_for_nextcloud

                run "sudo rm -f #{LOG}"
                make_request

                expect(timing_log_written?).to be false
        end

        scenario "is enabled in debug mode" do
                set_config mode: "debug"
                wait_for_nextcloud

                make_request

                # Apache can buffer log writes, so give it a few seconds
                wait_for("Timed out waiting for the Apache timing log to be written") do
                        timing_log_written?
                end

                # Verify the timing format: "<request>" <status> <µs> <bytes-in> <bytes-out>
                expect(`sudo cat #{LOG}`.lines.last).to match /"\S+ \S+ HTTP\/1\.1" \d+ \d+ \d+ \d+$/
        end

        protected

        def make_request
                # wait_for_nextcloud has already made requests, but make sure at least
                # one request happens after any config change settles
                run "curl -s http://localhost/ > /dev/null"
        end

        def timing_log_written?
                `sudo test -f #{LOG}`
                $?.to_i == 0 && !`sudo cat #{LOG}`.strip.empty?
        end
end
