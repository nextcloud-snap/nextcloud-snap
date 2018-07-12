feature "HTTP2" do
	scenario "Enable HTTP2" do
		
		# enable https and http/2
		enable_https
		enable_http2

		# test if http/2 is supported using a curl docker image (with http/2 support compiled in)
		http_version = `docker run -t --rm --network="host" registry.gitlab.com/bn4t/curl-http2-docker -sI --insecure https://localhost -o/dev/null -w '%{http_version}'`
		expect(http_version).to eq "2"
	end

	scenario "Disable HTTP2" do

		# disable http/2
		disable_http2

		# test if http/2 is supported using a curl docker image (with http/2 support compiled in)
		http_version = `docker run -t --rm --network="host" registry.gitlab.com/bn4t/curl-http2-docker -sI --insecure https://localhost -o/dev/null -w '%{http_version}'`
		expect(http_version).to eq "1.1"
	end
end
