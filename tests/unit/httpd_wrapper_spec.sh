Describe 'httpd-wrapper'
	Include src/apache/utilities/apache-utilities
	Include src/hooks/utilities/configuration-utilities

	AfterEach 'teardown'
	teardown()
	{
		snapctl reset
	}

	Mock httpd
		DEFINITIONS=""
		while getopts ":d:D:" opt; do
			case $opt in
				d)
					# Skip
					;;
				D)
					DEFINITIONS="$DEFINITIONS $OPTARG"
					;;
				\?)
					echo "Unsupported option: -$OPTARG" >&2
					exit 1
					;;
			esac
		done
		shift $((OPTIND-1))

		%preserve DEFINITIONS HTTP_PORT HTTPS_PORT
	End

	Describe 'handles ports that are'
		It 'standard'
			When call src/apache/bin/httpd-wrapper
			The output should be present
			The variable DEFINITIONS should equal ""
			The variable HTTP_PORT should equal "80"
			The variable HTTPS_PORT should equal "443"
		End

		It 'non-standard'
			apache_set_http_port 81
			apache_set_https_port 444

			When call src/apache/bin/httpd-wrapper
			The output should be present
			The variable DEFINITIONS should equal ""
			The variable HTTP_PORT should equal "81"
			The variable HTTPS_PORT should equal "444"
		End
	End

	Describe 'handles certificates that are'
		It 'active and good for hsts'
			export LIVE_CERTS_DIRECTORY="$(mktemp)"

			When call src/apache/bin/httpd-wrapper
			The output should include 'using HTTPS'
			The variable DEFINITIONS should include "EnableHTTPS"
			The variable DEFINITIONS should include "EnableHSTS"
		End

		It 'active and self-signed'
			export LIVE_CERTS_DIRECTORY="$(mktemp)"
			export SELF_SIGNED_DIRECTORY="$LIVE_CERTS_DIRECTORY"

			When call src/apache/bin/httpd-wrapper
			The output should include 'disabling HSTS'
			The variable DEFINITIONS should include "EnableHTTPS"
			The variable DEFINITIONS should not include "EnableHSTS"
		End
	End

	Describe 'handles compression that is'
		It 'default'
			When call src/apache/bin/httpd-wrapper
			The output should include 'compression is disabled'
			The variable DEFINITIONS should not include "EnableCompression"
		End

		It 'disabled'
			apache_disable_http_compression
			When call src/apache/bin/httpd-wrapper
			The output should include 'compression is disabled'
			The variable DEFINITIONS should not include "EnableCompression"
		End

		It 'enabled'
			apache_enable_http_compression
			When call src/apache/bin/httpd-wrapper
			The output should include 'compression is enabled'
			The variable DEFINITIONS should include "EnableCompression"
		End
	End

	Describe 'handles mode'
		It 'default'
			When call src/apache/bin/httpd-wrapper
			The output should be present
			The variable DEFINITIONS should not include "Debug"
		End

		It 'production'
			enable_production_mode
			When call src/apache/bin/httpd-wrapper
			The output should be present
			The variable DEFINITIONS should not include "Debug"
		End

		It 'debug'
			enable_debug_mode
			When call src/apache/bin/httpd-wrapper
			The output should be present
			The variable DEFINITIONS should include "Debug"
		End
	End
End
