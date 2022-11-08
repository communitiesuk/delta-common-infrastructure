# Update the policy created by AWS managed AD to match Datamart production
# https://docs.aws.amazon.com/directoryservice/latest/admin-guide/supportedpolicysettings.html 
Set-ADFineGrainedPasswordPolicy -Identity CustomerPSO-03 `
  -ComplexityEnabled $True -LockoutDuration 00:30:00 -LockoutObservationWindow 00:30:00 `
  -ReversibleEncryptionEnabled $False -MinPasswordAge 1.00:00:00 -MaxPasswordAge 90.00:00:00 `
  -MinPasswordLength 10 -LockoutThreshold 3 -PasswordHistoryCount 24

Add-ADFineGrainedPasswordPolicySubject -Identity CustomerPSO-03 -Subjects datamart-delta-user
