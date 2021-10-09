Describe 'configuration-utilities'
	Include src/hooks/utilities/configuration-utilities

    AfterEach 'teardown'
	teardown()
	{
		snapctl reset
	}

	Describe 'debug mode'
		It 'is disabled by default'
			When call debug_mode_enabled
			The status should be failure
		End

        It 'can be enabled'
            enable_debug_mode
			When call debug_mode_enabled
			The status should be success
		End

        It 'can be disabled'
            enable_debug_mode
            enable_production_mode
			When call debug_mode_enabled
			The status should be failure
		End
	End

    Describe 'production mode'
		It 'is enabled by default'
			When call production_mode_enabled
			The status should be success
		End

        It 'can be disabled'
            enable_debug_mode
			When call production_mode_enabled
			The status should be failure
		End

        It 'can be enabled'
            enable_debug_mode
            enable_production_mode
			When call production_mode_enabled
			The status should be success
		End
	End

    Describe 'mode_has_changed'
		It 'detects no changes by default'
			When call mode_has_changed
			The status should be failure
		End

        It 'ignores if both are debug'
            _set_mode "debug"
            _set_previous_mode "debug"
			When call mode_has_changed
			The status should be failure
		End

        It 'ignores if both are production'
            _set_mode "production"
            _set_previous_mode "production"
			When call mode_has_changed
			The status should be failure
		End

        It 'notices when current is debug and previous is production'
            enable_debug_mode
            _set_previous_mode "production"
			When call mode_has_changed
			The status should be success
		End

        It 'notices when current is production and previous is debug'
            enable_production_mode
            _set_previous_mode "debug"
			When call mode_has_changed
			The status should be success
		End
	End
End
