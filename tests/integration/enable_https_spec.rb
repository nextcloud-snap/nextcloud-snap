require 'fileutils'

feature "Enabling HTTPS" do
	after(:all) do
		disable_https
	end

	scenario "self-signed" do
		enable_https

		visit "/"
		fill_in "user", with: "admin"
		fill_in "password", with: "admin"
		click_button "Log in"
		sleep 3
		expect(page).to have_content /(Recommended|All) files/
	end

	# Test obtaining a certificate from an ACME server in CI without needing a
	# publicly-routable domain name or hitting the real Let's Encrypt service.
	# See issue #3465. It runs in a container, talks to Apache on localhost, and
	# issues real certificates signed by a throwaway CA.
	context "via an ACME server (Pebble, a synthetic Let's Encrypt)" do
		# Pin both container images to the same Pebble release.
		PEBBLE_VERSION = '2.10.1'
		PEBBLE_IMAGE = "ghcr.io/letsencrypt/pebble:#{PEBBLE_VERSION}"
		CHALLTESTSRV_IMAGE = "ghcr.io/letsencrypt/pebble-challtestsrv:#{PEBBLE_VERSION}"
		# The ACME endpoint certificates are downloaded from the same tag.
		PEBBLE_BASE_URL = "https://raw.githubusercontent.com/letsencrypt/pebble/v#{PEBBLE_VERSION}"
		WORKING_DIRECTORY = '/tmp/pebble-acme-test'
		CERTS_DIRECTORY = "#{WORKING_DIRECTORY}/certs"
		PEBBLE_CONFIG = "#{WORKING_DIRECTORY}/pebble-config.json"
		ACME_URL = 'https://localhost:14000/dir'
		MANAGEMENT_URL = 'https://localhost:15000'
		DOMAIN = 'localhost'
		PEBBLE_ROOT_CERT = "#{WORKING_DIRECTORY}/pebble-root.pem"
		PEBBLE_MINICA_CERT = '/var/snap/nextcloud/common/pebble.minica.pem'
		# This is $SNAP_CURRENT/certs/certbot, i.e. the working directory of
		# the certbot shipped by the snap (where lineages materialize)
		CERTBOT_DIRECTORY = '/var/snap/nextcloud/current/certs/certbot'
		CERTBOT_LIVE_DIRECTORY = "#{CERTBOT_DIRECTORY}/config/live/#{DOMAIN}"

		before(:all) do
			start_pebble
			obtain_certificate
		end

		after(:all) do
			# No need to disable_https here: the feature-level after(:all)
			# takes care of putting Apache back in HTTP mode. Use `system`
			# instead of `run` here: every step needs to happen even if a
			# previous one failed (say, because Pebble never started).
			system 'docker rm --force pebble pebble-challtestsrv > /dev/null 2>&1'
			system "sudo rm --force #{PEBBLE_MINICA_CERT}"
			system "sudo rm --recursive --force #{CERTBOT_DIRECTORY}"
			FileUtils.rm_rf WORKING_DIRECTORY
		end

		scenario "certbot obtains a certificate from Pebble and Apache serves it" do
			# The complete lineage should exist on disk (sudo since certbot
			# locks down the permissions on its config directory)
			lineage = `sudo ls #{CERTBOT_LIVE_DIRECTORY}`.split.sort
			expect(lineage).to eq %w[README cert.pem chain.pem fullchain.pem privkey.pem]

			# ... covering the expected dNSName
			san = `sudo openssl x509 -in #{CERTBOT_LIVE_DIRECTORY}/cert.pem -noout -ext subjectAltName`
			expect(san).to include "DNS:#{DOMAIN}"

			# Pebble regenerates its issuing hierarchy on every launch; ask
			# its management interface for the current root certificate...
			run "curl --silent --fail --insecure --output #{PEBBLE_ROOT_CERT} #{MANAGEMENT_URL}/roots/0"

			# ... and prove that Apache serves a certificate chain that
			# verifies against it (i.e. the Pebble-issued certificate, not
			# e.g. a self-signed one, which would also be happily served by
			# the browser tests that ignore certificate errors).
			wait_for_nextcloud(https: true)
			output = `curl --silent --fail --cacert #{PEBBLE_ROOT_CERT} https://#{DOMAIN}/status.php`
			expect($?.to_i).to eq 0
			expect(output).to include '"installed":true'
		end

		private

		def start_pebble
			unless system('command -v docker > /dev/null')
				fail 'Running this test requires Docker'
			end

			# Fetch the certificates (signed by Pebble's static test CA) that
			# Pebble needs to serve its own HTTPS endpoints, so that this test
			# works no matter how the container images are assembled. These
			# files are published in the repository for exactly this purpose.
			FileUtils.mkdir_p "#{CERTS_DIRECTORY}/localhost"
			{
				'test/certs/pebble.minica.pem' => "#{CERTS_DIRECTORY}/pebble.minica.pem",
				'test/certs/localhost/cert.pem' => "#{CERTS_DIRECTORY}/localhost/cert.pem",
				'test/certs/localhost/key.pem' => "#{CERTS_DIRECTORY}/localhost/key.pem",
			}.each do |source, destination|
				run "curl --silent --fail --location --output #{destination} " \
				    "#{PEBBLE_BASE_URL}/#{source}"
			end

			# Same configuration that Pebble ships by default, except that the
			# VA connects to ports 80/443 (where Apache listens) instead of
			# unprivileged ports, and that it uses the certificates downloaded
			# above.
			File.write(PEBBLE_CONFIG, <<~EOF)
				{
				  "pebble": {
				    "listenAddress": "0.0.0.0:14000",
				    "managementListenAddress": "0.0.0.0:15000",
				    "certificate": "/pebble-ci/certs/localhost/cert.pem",
				    "privateKey": "/pebble-ci/certs/localhost/key.pem",
				    "httpPort": 80,
				    "tlsPort": 443,
				    "ocspResponderURL": "",
				    "externalAccountBindingRequired": false,
				    "domainBlocklist": ["blocked-domain.example"],
				    "retryAfter": {
				      "authz": 3,
				      "order": 5
				    },
				    "keyAlgorithm": "ecdsa",
				    "profiles": {
				      "default": {
				        "description": "The profile you know and love",
				        "validityPeriod": 7776000
				      }
				    }
				  }
				}
			EOF

			# Pebble's DNS server, so that challenge validation requests for
			# the test domain deterministically resolve to the local Apache,
			# no matter what the host's resolver happens to say.
			run "docker run --detach --name pebble-challtestsrv --net=host --rm " \
			    "#{CHALLTESTSRV_IMAGE} -defaultIPv6 \"\" -defaultIPv4 127.0.0.1"

			# The ACME server itself. Skip the random validation sleeps and
			# nonce rejections that are designed to keep ACME clients honest--
			# don't want to (re)test certbot here, want a fast and
			# deterministic regression test for the snap.
			run "docker run --detach --name pebble --net=host --rm " \
			    "--env PEBBLE_VA_NOSLEEP=1 --env PEBBLE_WFE_NONCEREJECT=0 " \
			    "--volume #{WORKING_DIRECTORY}:/pebble-ci:ro " \
			    "#{PEBBLE_IMAGE} " \
			    "-config /pebble-ci/pebble-config.json -dnsserver 127.0.0.1:8053 " \
			    "-strict=false"

			begin
				wait_for 'Timed out waiting for the Pebble ACME server' do
					system "curl --silent --fail --insecure #{ACME_URL} > /dev/null"
				end
			rescue RuntimeError
				# Make startup failures diagnosable in the CI logs
				system 'docker logs pebble'
				raise
			end
		end

		def obtain_certificate
			# Pebble's ACME endpoint is served over HTTPS with a certificate
			# signed by a static test CA. Certbot needs to trust it when
			# talking to the ACME server; REQUESTS_CA_BUNDLE is the only way
			# to configure this (certbot uses requests, which ignores the
			# system trust store).
			run "sudo cp #{CERTS_DIRECTORY}/pebble.minica.pem #{PEBBLE_MINICA_CERT}"

            # CERTBOT_SERVER points certbot at Pebble instead of Let's
            # Encrypt (which requires a public, routable domain).
			run "printf 'y\\nci@test.com\\n#{DOMAIN}\\n' | " \
                "sudo env REQUESTS_CA_BUNDLE=#{PEBBLE_MINICA_CERT} " \
                "CERTBOT_SERVER=#{ACME_URL} nextcloud.enable-https lets-encrypt"
		end
	end
end
