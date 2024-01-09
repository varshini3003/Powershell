param($CurrentOwnerUid,$NewOwnerUid)
Import-Module PSSailPoint
function Get-IdentityId {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username
    )

    $search_body = @"
    {
        "indices": [
            "identities"
        ],
        "query": {
            "query": "attributes.uid:$Username"
        },
        "queryResultFilter":{
            "includes":[
                "id"
                ,"name"
                ,"owns"
            ]
        }
    }
"@

    $Search = ConvertFrom-JsonToSearch -Json $search_body
    try {
        $search_result = Search-Post -Search $Search
        Write-Host("entered search")
        Write-Host($search_result[0] | ConvertTo-Json -Depth 5)
        return $search_result
    } catch {
        Write-Host("Exception occurred when calling Search-Post: {0}" -f ($_.ErrorDetails | ConvertFrom-Json))
        Write-Host("Response headers: {0}" -f ($_.Exception.Response.Headers | ConvertTo-Json))
    }
}
$current_owner = Get-IdentityId -Username $CurrentOwnerUid

if ($current_owner -ne $null -and $current_owner.Count -gt 0) {
    Write-Host("Current Owner ID: $($current_owner[0].id)")
    # Continue with the rest of your script
} else {
    Write-Host("No matching identity found for CurrentOwnerUid: $CurrentOwnerUid")
}

function Update-ObjectOwnership{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id,
        [Parameter(Mandatory=$true)]
        [string]$Type,
        [Parameter(Mandatory=$true)]
        [string]$NewOwnerId
    )
    $request_body = @"
    {
        "op": "replace",
        "path": "/owner",
        "value":
            {
                "id":"$NewOwnerId",
                "type":"IDENTITY"
            }
    }
"@
    try {
        if($Type -eq "SOURCE"){
            Update-Source -Id $Id -JsonPatchOperation ($request_body | ConvertFrom-Json)
        }
        if($Type -eq "ROLE"){
            Update-Role -Id $Id -JsonPatchOperation ($request_body | ConvertFrom-Json)
        }
        if($Type -eq "ACCESSPROFILE"){
            Update-AccessProfile -Id $Id -JsonPatchOperation ($request_body | ConvertFrom-Json)
        }
        if($Type -eq "ENTITLEMENT"){
            Update-BetaEntitlement -Id $Id -JsonPatchOperation ($request_body | ConvertFrom-Json)
        }
    } catch {
        Write-Host ("Exception occurred when calling Update-ObjectOwnership for {0} {1}: {2}" -f ($Type,$Id,$_.ErrorDetails))
    }
}


$current_owner = Get-IdentityId -Username $CurrentOwnerUid
Write-Host($current_owner)
$new_owner = Get-IdentityId -Username $NewOwnerUid
Write-Host($new_owner)
Write-Host("new Owner Object: $($new_owner | ConvertTo-Json -Depth 5)")



foreach($source in $current_owner.owns.sources){
    Update-ObjectOwnership -Id $source.id -NewOwnerId $new_owner.id -Type "SOURCE"
}
foreach($role in $current_owner.owns.roles){
    Update-ObjectOwnership -Id $role.id -NewOwnerId $new_owner.id -Type "ROLE"
}
foreach($access_profile in $current_owner.owns.accessProfiles){
    Update-ObjectOwnership -Id $access_profile.id -NewOwnerId $new_owner.id -Type "ACCESSPROFILE"
}
foreach($entitlement in $current_owner.owns.entitlements){
    Update-ObjectOwnership -Id $entitlement.id -NewOwnerId $new_owner.id -Type "ENTITLEMENT"
}
