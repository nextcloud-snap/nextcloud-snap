require 'net/http'

feature "Change http compression" do
	after(:all) do
		set_config "http.compression": "false"
		wait_for_nextcloud
	end

	scenario "invalid" do
		# This will print to stderr. Redirect so we can capture it easily.
		output=`sudo snap set nextcloud http.compression=invalid 2>&1`
		expect($?.to_i).to_not eq 0
		expect(output).to include "value must be either 'true' or 'false'"
	end

	scenario "compression" do
		assert_apache_compression_default

		set_config "http.compression": "true"
		wait_for_nextcloud

		assert_apache_compression
	end

	protected

	def assert_apache_compression_default
		# Verify that Apache is not returning compressed reponses
		response = nextcloud_response
                puts response.to_hash
		expect(response["content-encoding"]).to eq nil
	end

	def assert_apache_compression
		# Verify that Apache is returning compressed reponses
		response = nextcloud_response
                puts response.to_hash
		expect(response["content-encoding"]).to include "br"
	end

	def nextcloud_response(url: "http://localhost/core/img/favicon.ico")
		uri = URI(url)
		req = Net::HTTP::Get.new(uri)
		req['Accept-Encoding'] = "gzip, deflate, br"
		res = Net::HTTP.start(uri.hostname, uri.port) {|http|
			http.request(req)
		}
		return res
	end
end
