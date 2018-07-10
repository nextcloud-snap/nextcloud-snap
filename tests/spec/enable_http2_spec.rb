feature "Enabling HTTP2" do

	install_http2_cli
	enable_http2

	`is-http2 localhost`
	expect($?.split("\n").first).to eq "✓ HTTP/2 supported by localhost"
end
