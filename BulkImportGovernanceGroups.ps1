[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$orgName = Read-Host -Prompt "Enter your Tenant name"
$clientID = Read-Host -Prompt "Enter your Client ID"
$clientSecret = Read-Host -Prompt "Enter your Client Secret"
# Get v3 oAuth Token
# oAuth URI
$oAuthURI = "https://$($orgName).api.identitynow-demo.com/oauth/token"
$v3Token = Invoke-RestMethod -Method Post -Uri "$($oAuthURI)?grant_type=client_credentials&client_id=$($clientID)&client_secret=$($clientSecret)"
#echo $v3Token

$ownerName = Read-Host -Prompt "Enter your Governance Group Owner name"
#echo $ownerName

$body = @"
{
  `"indices`": [
    `"identities`"
  ],
  `"query`": {
    `"query`": `"attributes.uid:$ownerName`"
  }
}
"@

#echo $body
		
$owner = Invoke-RestMethod -Method POST -Uri "https://$($orgName).api.identitynow-demo.com/v3/search" -Headers @{Authorization = "$($v3Token.token_type) $($v3Token.access_token)"; "content-type" = "application/json"} -Body $body
#echo $owner

$GovGroupOwner = $owner[0]

#echo $GovGroupOwner
$fileName = Read-Host -Prompt "Enter Fullpath name for the file to be imported"
Import-Csv $fileName |`
ForEach-Object {
    if ($v3Token.access_token) {
        try {
            $body = @{"name" = $_.Name;
                    "displayName" = $_.Name;
                    "description" = $_.Name;
                    "owner" = @{"displayName" = $GovGroupOwner.displayName;
                    "emailAddress" =  $GovGroupOwner.email;
                    "id" = $GovGroupOwner.id;
                    "name" = $GovGroupOwner.name
                }
            }

            $body = $body | Convertto-json 

            try {          
                $IDNNewGroup = Invoke-RestMethod -Method Post -Uri "https://$($orgName).api.identitynow-demo.com/beta/workgroups?&org=$($orgName)" -Headers @{Authorization = "$($v3Token.token_type) $($v3Token.access_token)"; "Content-Type" = "application/json"} -Body $body
                if ($IDNNewGroup.id -ne $null){
                    Write-Host -ForegroundColor Green "Created Governance Group: $($IDNNewGroup.name)"
					#write-host -ForegroundColor Green $IDNNewGroup.id
                }
            }
            catch {
                Write-Error "Failed to create group. Check group details. $($_)" 
            }

            # Add members
				$memberBody = @"
[
"@

            foreach ($user in $_.Users.Split(";"))
            {
				$userBody = @"
{
  `"indices`": [
	`"identities`"
  ],
  `"query`": {
	`"query`": `"attributes.uid.exact:$user`"
  }
}
"@
				#write-host $userBody
                $govGroupMember = Invoke-RestMethod -Method POST -Uri "https://$($orgName).api.identitynow-demo.com/v3/search" -Headers @{Authorization = "$($v3Token.token_type) $($v3Token.access_token)"; "content-type" = "application/json" } -Body $userBody
                $govGroupMember = $govGroupMember | Sort-Object | Select-Object -Property id, name -Unique
				#write-host $govGroupMember
					
$memberBody = $memberBody + @"
{
	`"type`": `"IDENTITY`",
    `"id`": `"$($govGroupMember.id)`",
    `"name`": `"$($govGroupMember.name)`"
},
"@
			}

$memberBody = $memberBody.substring(0, $memberBody.length - 1)
$memberBody = $memberBody + @"
]
"@
			
			#write-host $memberBody

            # GovernanceGroup Update URI
            $govGroupMembersURI = "https://$($orgName).api.identitynow-demo.com/beta/workgroups/$($IDNNewGroup.id)/members/bulk-add"
			#write-host $govGroupMembersURI
			
            # Update Goverance Group
            Invoke-RestMethod -Uri $govGroupMembersURI -Method POST -Body $memberBody -Headers @{Authorization = "$($v3Token.token_type) $($v3Token.access_token)"; "Content-Type" = "application/json"}
            Write-Host -ForegroundColor Green "Added Members to Governance Group: $($IDNNewGroup.name)"
			Write-Host ""
        }
        catch {
            Write-Error "Group doesn't exist. Check group ID. $($_)" 
        }
    }
    else {
        Write-Error "Authentication Failed. Check your AdminCredential and v3 API ClientID and ClientSecret. $($_)"
    }
}
