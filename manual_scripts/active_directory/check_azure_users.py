# Python script to check whether a list of users exists in DLUHC Azure AD.
# Used during the SSO switchover to make sure we are not going to lock users out.
# Needs a valid bearer token for Microsoft Graph

# Expects a list of user emails in prod_dluhc_users.txt, can get this from the AD Management Server (Powershell)
# $date = (get-date).AddDays(-90)
# $fdate = $date.tofiletime()
# Get-ADUser -Filter {(LastLogonTimeStamp -gt $fdate -AND enabled -eq $true -AND mail -like "*@levellingup.gov.uk")} -Properties mail | Select-Object -Property mail

import requests

jwt = "Fill me in"

def user_exists(user: str) -> bool:
    headers = {'Authorization': 'Bearer ' + jwt}
    response = requests.get("https://graph.microsoft.com/v1.0/users/" + user, headers=headers)

    if (response.status_code == 200):
        return True
    elif (response.status_code == 404):
        return False
    else:
        raise Exception("Unexpected response " + response.status_code + " for user " + user)

def find_user_from_proxy_address(email: str) -> dict:
    headers = {'Authorization': 'Bearer ' + jwt}
    response = requests.get(f"https://graph.microsoft.com/v1.0/users?$count=true&$filter=proxyAddresses/any(a:a eq 'smtp:{email}')&$select=id,displayName,userPrincipalName,mail,proxyAddresses,jobTitle", headers=headers)

    if (response.status_code != 200):
        raise Exception("Unexpected response " + response.status_code + " for proxy email " + email)

    users = response.json()["value"]
    if (len(users) > 1):
        raise Exception("More than one user returned for " + email)

    if (len(users) == 0):
        return None

    return users[0]


with open("prod_dluhc_users.txt", 'r') as file:
    emails = [line.strip() for line in file if line.strip()]

existing = []
nonExisting = []

for email in emails:
    azName = email.replace("levellingup.gov.uk", "communities.gov.uk")
    exists = user_exists(azName)
    if (exists):
        existing.append(email)
    else:
        nonExisting.append(email)
    print(f"Email: {email} - Exists: {exists}")

print(f"{len(existing)} accounts exist in Azure")

print(f"{len(nonExisting)} accounts missing in Azure")

print("\n".join(nonExisting) + "\n")

for email in nonExisting:
    user = find_user_from_proxy_address(email)
    if (user != None):
        if (user['jobTitle']):
            print(f"Found account for user {email}: {user['userPrincipalName']} ({user['displayName']}, {user['jobTitle'].strip()})")
        else:
            print(f"Found account for user {email}: {user['userPrincipalName']} ({user['displayName']})")

    else:
        print(f"No account found for user {email}")
