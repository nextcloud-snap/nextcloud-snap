require 'net/http'

feature "Change operating mode" do
	after(:all) do
		set_config mode: "production"
		wait_for_nextcloud
	end

	scenario "production" do
		set_config mode: "production"
		wait_for_nextcloud

		assert_apache_prod_tokens
		assert_apache_no_signature
		assert_php_no_signature
	end

	scenario "debug" do
		set_config mode: "debug"
		wait_for_nextcloud

		assert_apache_full_tokens
		assert_apache_signature
		assert_php_signature
	end

	scenario "invalid" do
		# This will print to stderr. Redirect so we can capture it easily.
		output=`sudo snap set nextcloud mode=invalid 2>&1`
		expect($?.to_i).to_not eq 0
		expect(output).to include "mode must be either 'debug' or 'production'"
	end

	protected

	def assert_apache_prod_tokens
		# Verify that Apache clamps down on the server string and stops sending
		# version and OS information.
		expect(nextcloud_response["server"]).to eq "Apache"
	end

	def assert_apache_full_tokens
		# Verify that Apache opens up the server string and sends version and
		# OS information.
		expect(nextcloud_response["server"]).to match /Apache\/2\.4\.\d+ \(Unix\)/
	end

	def assert_apache_no_signature
		# Verify that no signature is shown on e.g. 404 pages
		response = nextcloud_response(url: "http://localhost/give-me-a-404")
		expect(response.body.downcase).to_not include "apache"
	end

	def assert_apache_signature
		# Verify that a signature is shown on e.g. 404 pages
		response = nextcloud_response(url: "http://localhost/give-me-a-404")
		expect(response.body.downcase).to include "apache"
	end

	def assert_php_no_signature
		# Verify that PHP doesn't add an X-Powered-By header
		expect(nextcloud_response.to_hash).to_not include "x-powered-by"
	end

	def assert_php_signature
		# Verify that PHP adds an X-Powered-By header
		response = nextcloud_response
		expect(response.to_hash).to include "x-powered-by"
		expect(response["x-powered-by"]).to match /PHP\/8\.1\.\d+/
	end

	def nextcloud_response(url: "http://localhost")
		return Net::HTTP.get_response(URI(url))
	end
end
