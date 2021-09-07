feature "Change ports" do
	feature "http" do
		after(:all) do
			set_config "ports.http": 80, "ports.https": 443
			wait_for_nextcloud
		end

		scenario "http" do
			set_config "ports.http": 81
			expect($?.to_i).to eq 0
			wait_for_nextcloud(port: 81)
			Capybara.app_host = 'http://localhost:81'

			visit "/"
			assert_uri(https: false, port: 81)

			# Also assert that we can change it back to the default
			set_config "ports.http": 80
			expect($?.to_i).to eq 0
			wait_for_nextcloud
			Capybara.app_host = 'http://localhost'

			visit "/"
			assert_uri(https: false, port: 80)
		end
	end

	feature "https" do
		before(:all) do
			enable_https
		end

		after(:all) do
			set_config "ports.http": 80, "ports.https": 443
			wait_for_nextcloud
			disable_https
		end

		scenario "https" do
			set_config "ports.https": 444
			expect($?.to_i).to eq 0
			wait_for_nextcloud(https: true, port: 444)
			Capybara.app_host = 'https://localhost:444'

			visit "/"
			assert_uri(https: true, port: 444)

			# Also assert that we can change it back to the default
			set_config "ports.https": 443
			expect($?.to_i).to eq 0
			wait_for_nextcloud(https: true)
			Capybara.app_host = 'https://localhost'

			visit "/"
			assert_uri(https: true, port: 443)
		end


		scenario "http still redirects to unchanged https" do
			set_config "ports.http": 81
			expect($?.to_i).to eq 0
			wait_for_nextcloud(port: 81)
			Capybara.app_host = 'http://localhost:81'

			visit "/"
			assert_uri(https: true, port: 443)
		end


		scenario "http redirects to changed https" do
			set_config "ports.http": 81, "ports.https": 444
			expect($?.to_i).to eq 0
			wait_for_nextcloud(port: 81)
			Capybara.app_host = 'http://localhost:81'

			visit "/"
			assert_uri(https: true, port: 444)
		end

		scenario "Let's Encrypt challenge request" do
			# Assert we do not redirect under the four possibilities for
			# changing or not changing ports
			assert_lets_encrypt_challenge(http_port: 80, https_port: 443)
			assert_lets_encrypt_challenge(http_port: 80, https_port: 444)
			assert_lets_encrypt_challenge(http_port: 81, https_port: 443)
			assert_lets_encrypt_challenge(http_port: 81, https_port: 444)
		end
	end

	protected

	def assert_uri(https:, port:)
		uri = URI.parse(current_url)
		if https
			expect(uri.scheme).to eq 'https'
		else
			expect(uri.scheme).to eq 'http'
		end

		expect(uri.host).to eq 'localhost'
		expect(uri.port).to eq port
	end

	def assert_lets_encrypt_challenge(http_port:, https_port:)
		set_config "ports.http": http_port, "ports.https": https_port
		expect($?.to_i).to eq 0
		wait_for_nextcloud(https: false, port: http_port)
		Capybara.app_host = "http://localhost:#{http_port}"

		visit "/.well-known/acme-challenge/a-challenge-path"
		assert_uri(https: false, port: http_port)
	end
end
