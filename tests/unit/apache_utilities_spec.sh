Describe 'apache-utilities'
	Include src/apache/utilities/apache-utilities

	AfterEach 'teardown'
	teardown()
	{
		snapctl reset
	}

	Describe 'apache pid function'
		BeforeEach 'setup'
		AfterEach 'teardown'
		setup()
		{
			APACHE_PIDFILE="$(mktemp)"
		}
		teardown()
		{
			rm -f "$APACHE_PIDFILE"
		}

		Describe 'apache_pid'
			It 'fails gracefully when apache is not running'
				rm -f "$APACHE_PIDFILE"

				When call apache_pid
				The output should equal ''
				The error should equal "Unable to get Apache PID as it's not yet running"
			End

			It 'returns pid when apache is running'
				echo '42' > "$APACHE_PIDFILE"
				When call apache_pid
				The output should equal '42'
			End
		End

		Describe 'apache_is_running'
			It 'fails when apache is not running'
				rm -f "$APACHE_PIDFILE"

				When call apache_is_running
				The status should be failure
				The output should equal ''
			End

			It 'succeeds when apache is running'
				When call apache_is_running
				The status should be success
				The output should equal ''
			End
		End
	End

	Describe 'apache_http_port'
		It 'defaults to 80'
			When call apache_http_port
			The output should equal '80'
		End

		It 'supports being changed'
			apache_set_http_port 81
			When call apache_http_port
			The output should equal '81'
		End
	End

	Describe 'apache_https_port'
		It 'defaults to 443'
			When call apache_https_port
			The output should equal '443'
		End

		It 'supports being changed'
			apache_set_https_port 444
			When call apache_https_port
			The output should equal '444'
		End
	End

	Describe 'apache_get_http_compression'
		It 'defaults to false'
			When call apache_get_http_compression
			The output should equal 'false'
		End

		It 'supports being enabled'
			apache_enable_http_compression
			When call apache_get_http_compression
			The output should equal 'true'
		End

		It 'supports being disabled'
			apache_enable_http_compression
			apache_disable_http_compression
			When call apache_get_http_compression
			The output should equal 'false'
		End
	End

	Describe 'apache_http_compression_enabled'
		It 'defaults to false'
			When call apache_http_compression_enabled
			The status should be failure
			The output should equal ''
			The error should equal ''
		End

		It 'supports being enabled'
			apache_enable_http_compression
			When call apache_http_compression_enabled
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'supports being disabled'
			apache_enable_http_compression
			apache_disable_http_compression
			When call apache_http_compression_enabled
			The status should be failure
			The output should equal ''
			The error should equal ''
		End
	End

	Describe 'apache_http_compression_has_changed'
		It 'default to false'
			When call apache_http_compression_has_changed
			The status should be failure
			The output should equal ''
			The error should equal ''
		End

		It 'notices when previous is true and current is false'
			apache_disable_http_compression
			_apache_set_previous_http_compression "true"
			When call apache_http_compression_has_changed
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'notices when previous is false and current is true'
			apache_enable_http_compression
			_apache_set_previous_http_compression "false"
			When call apache_http_compression_has_changed
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'ignores if both are true'
			apache_enable_http_compression
			When call apache_http_compression_has_changed
			The status should be failure
			The output should equal ''
			The error should equal ''
		End

		It 'ignores if both are false'
			apache_disable_http_compression
			When call apache_http_compression_has_changed
			The status should be failure
			The output should equal ''
			The error should equal ''
		End
	End
End
