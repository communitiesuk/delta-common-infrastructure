Import-Module ActiveDirectory

# Used during Barnsley/Sheffield merger to to add new ons versions of users access groups
# Set Old/NewOns and OrgName variables respectively to use

# Testing Ons
$OrgName = 'Softwire'
$OldOns = 'S1234'
$NewOns = 'S9876'

# $OrgName = 'Barnsley'
# $OldOns = 'E08000016'
# $NewOns = 'E08000038'

# $OrgName = 'Sheffield'
# $OldOns = 'E08000019'
# $NewOns = 'E08000039'

# Creates new ad group if one does not already exist
function Create-Group {
	param (
		$NewGroup
	)
    # Gets the name and path of the new group to be created from the new groups identity param passed in
    # $New Group = CN=datamart-delta-abatements-approvers-S9876,OU=Groups,OU=dluhcdata,DC=dluhcdata,DC=local
    # $name = datamart-delta-abatements-approvers-S9876
    # $path = OU=Groups,OU=dluhcdata,DC=dluhcdata,DC=local
	$strings = $NewGroup -split ","
	$name = $strings[0].Substring(3)
	$path = $strings[1..($strings.length -1)] -join ','
	try {
		New-ADGroup -Name $name -GroupCategory Security -GroupScope Global -Path $path
	}
	catch {
		Write-Host "Error during creation"
   		Write-Error $_.Exception.Message
	}

}

# List of users belonging to old organisation incl. member of
$Identity = 'CN=datamart-delta-user-' + $OldOns + ',OU=Groups,OU=dluhcdata,DC=dluhcdata,DC=local'
$Users = Get-ADGroupMember -Identity $Identity | Get-ADUser -Property MemberOf

foreach($User in $Users) {
	Write-Host "Updating: " $User.UserPrincipalName
	$ExistingGroups = $User | Select-Object -ExpandProperty MemberOf
	$OldGroups = $ExistingGroups | where {$_ -like '*' + $OldOns + '*'}
	foreach($OldGroup in $OldGroups) {
		$NewGroup = $OldGroup.Replace($OldOns,$NewOns)
		if ($ExistingGroups -NotContains $NewGroup) {
			try{
				# Add user to group
            	Add-ADGroupMember -Identity $NewGroup -Members $User.SamAccountName
			}
			# Specific exception thrown if the access group does not already exist
			catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
				# Create new access group
				Write-Host "Creating " $NewGroup
				Create-Group($NewGroup)
				# Add user to group
				Add-ADGroupMember -Identity $NewGroup -Members $User.SamAccountName
				Write-Host "Successfully added to group: " $NewGroup
			}
			catch {
				Write-Host "Unhandled Error!"
   				Write-Error $_.Exception.Message
			}
        	}
	}
	# Update comment
	$UserWithComment = $User | Get-ADUser -Property Comment
	$UserWithComment.Comment = $UserWithComment.Comment + "`nUpdated by script to add new " + $OrgName + " AD groups"
	Set-ADUser -Instance $UserWithComment
}
