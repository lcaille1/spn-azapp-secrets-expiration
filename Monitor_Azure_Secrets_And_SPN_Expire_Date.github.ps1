#Settings
$TimeSpanInDays=60

# Email report config
$EmailServer = "mail.smtp.com"
$fromEmailAddress = "mail@mail.com"
$EmailRecipients =  "group1@mail.com","group2@mail.com"
$EmailSubject = "Azure SPN, Secrets, AZApp, Expiration Report"

#Azure App Credentials to get Apps and SP
$EXPIRE_AppId = '12345678-1234-12345-4568-555555555'
$EXPIRE_secret = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

$tenantID = '12345678-1234-12345-4568-555555555'

#Azure App Credentials to send the Mail
$MAIL_AppId = '12345678-1234-12345-4568-555555555'
$MAIL_secret = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

#STOP HERE!

#-----------------------------------------------------------[Functions]------------------------------------------------------------
Function Email {
	Send-MailMessage -To $EmailRecipients -From $fromEMailAddress -Subject $EmailSubject -Body ($BodyJsonsend | Out-String) -BodyAsHtml -SmtpServer $EmailServer
 
}
#Invoke-RestMethod -Method POST -Uri $URLsend -Headers $MAIL_headers -Body $BodyJsonsend
#-----------------------------------------------------------[Script]------------------------------------------------------------

#Connect to GRAPH API with EXPIRE credentials
$EXPIRE_tokenBody = @{
    Grant_Type    = "client_credentials"
    Scope         = 'https://graph.microsoft.com/.default'
    Client_Id     = $EXPIRE_AppId
    Client_Secret = $EXPIRE_secret
}

$EXPIRE_tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantID/oauth2/v2.0/token" -Method POST -Body $EXPIRE_tokenBody
#"`n"
#write-Output ("token response = [$EXPIRE_tokenResponse]")
$EXPIRE_headers = @{
    "Authorization" = "Bearer $($EXPIRE_tokenResponse.access_token)"
    "Content-type"  = "application/json"
}


#Build Array to store PSCustomObject
$Array = @()



# List Get all Apps from Azure
$URLGetApps = "https://graph.microsoft.com/v1.0/applications"
$AllApps = Invoke-RestMethod -Method GET -Uri $URLGetApps -Headers $EXPIRE_headers

#write-Output ("AllApps")
#$AllApps


#Go through each App and add to our Array
foreach ($App in $AllApps.value) {

    $URLGetApp = "https://graph.microsoft.com/v1.0/applications/$($App.ID)"
    $App = Invoke-RestMethod -Method GET -Uri $URLGetApp -Headers $EXPIRE_headers

    if ($App.passwordCredentials) {
        foreach ($item in $App.passwordCredentials) {
            $Array += [PSCustomObject]@{
                "Type"           = "AZAPP"
                "displayName"    = $app.displayName
                "ID"             = $App.ID
                "AppID"          = $app.appId
                "SecType"        = "Secret"
                "Secret"         = $item.displayName
                "Secret-EndDate" = (Get-date $item.endDateTime)
               }
               

                }
    }
    

    if ($App.keyCredentials) {
        foreach ($item in $App.keyCredentials) {
            $Array += [PSCustomObject]@{
                'Type'           = "AZAPP"
                'displayName'    = $app.displayName
                'ID'             = $App.ID
                'AppID'          = $app.appId
                'SecType'        = "Zert"
                'Secret'         = $item.displayName
                'Secret-EndDate' = (Get-date $item.endDateTime)
            }
        }
    }
}




#Get all Service Principals
$servicePrincipals = "https://graph.microsoft.com/v1.0/servicePrincipals"
$SP = Invoke-RestMethod -Method GET -Uri $servicePrincipals -Headers $EXPIRE_headers
$SPList = $SP.value 
$UserNextLink = $SP."@odata.nextLink"
  

while ($UserNextLink -ne $null) {

    $SP = (Invoke-RestMethod -Uri $UserNextLink -Headers $EXPIRE_headers -Method Get )
    $UserNextLink = $SP."@odata.nextLink"
    $SPList += $SP.value
}
#$SPList|ConvertTo-Html| Out-File -FilePath d:\temp\SPList1.html -Force -Confirm:$false

#Go through each SP and add to our Array
foreach ($SAML in $SPList) {
    if ($Saml.passwordCredentials) {
        foreach ($PW in $Saml.passwordCredentials) {
            $Array += [PSCustomObject]@{
                'Type'           = "SP"
                'displayName'    = $SAML.displayName
                'ID'             = $SAML.id
                'AppID'          = $Saml.appId
                'SecType'        = "Secret"
                'Secret'         = $PW.displayName
                'Secret-EndDate' = (Get-date $PW.endDateTime)
            }
        }
    }
    #$Array|ConvertTo-Html| Out-File -FilePath d:\temp\Array.html -Force -Confirm:$false
}

$ExpireringZerts = $Array | Where-Object -Property Secret-EndDate -Value (Get-Date).AddDays($TimeSpanInDays) -lt  | Where-Object -Property Secret-EndDate -Value (Get-Date) -gt|ConvertTo-Html
$ExpireringZerts = $ExpireringZerts|select -Unique
#$ExpireringZerts| Out-File -FilePath d:\temp\ExpiringZerts.html -Force -Confirm:$false
#"`n"
#write-Output ("Expiring Zerts = [$ExpireringZerts]")                  

If($ExpireringZerts.Count -eq 0){

    $BodyJsonsend = "No resource will expire soon."

       Email `
        -EmailBody $BodyJsonsend `
        -ToEmailAddress $EmailRecipients `
        -Subject $EmailSubject `
        -fromEmailAddress $fromEMailAddress
#write-output -InputObject "Empty Body is [$BodyJsonsend]"

} else {
#    write-output -InputObject "NotEmpty Body is [$HTML]"
#      $Body = [string]($HTML | ConvertTo-Html -Head $Header)


$BodyJsonsend ="<p>Scanning EndDate<p>"
$BodyJsonsend +="<p>SPN,Secrets,Azure APP<p>"
$BodyJsonsend +="<p>Expiring until $($TimeSpanInDays) days<p>"
$BodyJsonsend += $ExpireringZerts

       

        Email `
            -EmailBody $BodyJsonsend `
            -ToEmailAddress $EmailRecipients `
            -Subject $EmailSubject `
			-fromEmailAddress $fromEMailAddress

        # No new resources. Send an email as such.
     
    }

