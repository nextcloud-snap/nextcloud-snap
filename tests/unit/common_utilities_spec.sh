Describe 'common-utilities'
	Include src/common/utilities/common-utilities
	Describe 'version_less_than'
		It 'handles less than'
			When call version_less_than '1.2.3' '1.2.4'
			The status should be success
		End

		It 'handles greater than'
			When call version_less_than '1.2.4' '1.2.3'
			The status should be failure
		End

		It 'handles equal'
			When call version_less_than '1.2.3' '1.2.3'
			The status should be failure
		End

		It 'handles daily less than'
			When call version_less_than '18-2021-05-14' '18-2021-05-15'
			The status should be success
		End

		It 'handles daily greater than'
			When call version_less_than '18-2021-05-15' '18-2021-05-14'
			The status should be failure
		End

		It 'handles daily equal'
			When call version_less_than '18-2021-05-15' '18-2021-05-15'
			The status should be failure
		End
	End

	Describe 'major_version'
		It 'handles empty strings'
			When call major_version ''
			The status should be success
			The output should equal ''
		End

		It 'handles semver'
			When call major_version '1.2.3'
			The status should be success
			The output should equal '1'
		End

		It 'handles snap version'
			When call major_version '1.2.3snap4'
			The status should be success
			The output should equal '1'
		End

		It 'handles daily versions'
			When call major_version '18-2021-05-15'
			The status should be success
			The output should equal '18'
		End
	End

	Describe 'is_integer'
		It 'handles strings'
			When call is_integer 'foo'
			The status should be failure
		End

		It 'handles floats'
			When call is_integer '1.2'
			The status should be failure
		End

		It 'handles integers'
			When call is_integer '1'
			The status should be success
		End
	End

	Describe 'is_semver'
		It 'rejects integer'
			When call is_semver '1'
			The status should be failure
		End

		It 'rejects float'
			When call is_semver '1.2'
			The status should be failure
		End

		It 'rejects daily version'
			When call is_semver '18-2021-05-15'
			The status should be failure
		End

		It 'accepts valid semver'
			When call is_semver '1.2.3'
			The status should be success
		End

		It 'accepts snap version'
			When call is_semver '1.2.3snap4'
			The status should be success
		End
	End

	Describe 'is_supported_nextcloud_upgrade'
		It 'handles no previous version'
			When call is_supported_nextcloud_upgrade '' '1.2.3'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'handles no current version'
			When call is_supported_nextcloud_upgrade '1.2.3' ''
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'handles same version'
			When call is_supported_nextcloud_upgrade '1.2.3' '1.2.3'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'errors on downgrade'
			When call is_supported_nextcloud_upgrade '1.2.3' '1.2.2'
			The status should be failure
			The output should equal ''
			The error should match pattern "[Nn]extcloud doesn't support downgrades*"
		End

		It 'handles minor upgrade'
			When call is_supported_nextcloud_upgrade '1.2.3' '1.2.4'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'handles major upgrade'
			When call is_supported_nextcloud_upgrade '1.2.3' '2.0.0'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'errors on daily downgrade'
			When call is_supported_nextcloud_upgrade '18-2021-05-15' '18-2021-05-14'
			The status should be failure
			The output should equal ''
			The error should match pattern "[Nn]extcloud doesn't support downgrades*"
		End

		It 'handles minor daily upgrade'
			When call is_supported_nextcloud_upgrade '18-2021-05-15' '18-2021-05-16'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'handles major daily upgrade'
			When call is_supported_nextcloud_upgrade '18-2021-05-15' '19-2021-05-15'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'handles switching from daily to stable'
			When call is_supported_nextcloud_upgrade '18-2021-05-15' '19.0.12snap1'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'handles switching from stable to daily'
			When call is_supported_nextcloud_upgrade '18.0.12snap1' '18-2021-05-15'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'handles switching from stable to master'
			When call is_supported_nextcloud_upgrade '18.0.12snap1' 'master-2021-05-15'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'handles switching from master to stable'
			When call is_supported_nextcloud_upgrade 'master-2021-05-15' '18.0.12snap1'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'handles switching from daily to master'
			When call is_supported_nextcloud_upgrade '18-2021-05-15' 'master-2021-05-15'
			The status should be success
			The output should equal ''
			The error should equal ''
		End

		It 'handles switching from master to daily'
			When call is_supported_nextcloud_upgrade 'master-2021-05-15' '18-2021-05-15'
			The status should be success
			The output should equal ''
			The error should equal ''
		End
	End
End
