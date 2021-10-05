Describe 'apache-utilities'
	Include src/apache/utilities/apache-utilities

	AfterEach 'teardown'
	teardown()
	{
		snapctl reset
	}

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
