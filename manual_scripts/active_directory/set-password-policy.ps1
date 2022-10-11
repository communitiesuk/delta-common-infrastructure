# Policy taken from Datamart prod

Set-ADDefaultDomainPasswordPolicy -Identity dluhcdata.local -ComplexityEnabled $True `
 -LockoutDuration 00:30:00 -LockoutObservationWindow 00:30:00 `
 -ReversibleEncryptionEnabled $False -MinPasswordAge 1.00:00:00 -MaxPasswordAge 90.00:00:00 `
 -MinPasswordLength 10 -LockoutThreshold 3 -PasswordHistoryCount 24
