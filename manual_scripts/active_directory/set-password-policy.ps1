# Update the policy created by AWS managed AD to match Datamart production
# https://docs.aws.amazon.com/directoryservice/latest/admin-guide/supportedpolicysettings.html 
Set-ADFineGrainedPasswordPolicy -Identity CustomerPSO-03 `
  -ComplexityEnabled $False -LockoutDuration 00:30:00 -LockoutObservationWindow 00:30:00 `
  -ReversibleEncryptionEnabled $False -MinPasswordAge 0 -MaxPasswordAge 365.00:00:00 `
  -MinPasswordLength 0 -LockoutThreshold 3 -PasswordHistoryCount 1 `
  -Description "Delta User Policy"

Add-ADFineGrainedPasswordPolicySubject -Identity CustomerPSO-03 -Subjects datamart-delta-user

Set-ADFineGrainedPasswordPolicy -Identity CustomerPSO-01 `
  -ComplexityEnabled $False -ReversibleEncryptionEnabled $False -LockoutThreshold 0 `
  -MinPasswordAge 0 -MaxPasswordAge 0 -MinPasswordLength 0 -PasswordHistoryCount 0 `
  -Description "Service User Policy"

Add-ADFineGrainedPasswordPolicySubject -Identity CustomerPSO-01 -Subjects dluhc-service-users
