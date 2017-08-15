##############################################################################################################
# PowerShell Script to add a Relying Party trust in a ADFS Server
# Author: Krishna Swarup
# NOTE: TransformRules.txt file need to be copied accessible to this script and the path should be specified 
# USAGE: ADFSRelyingPartyTrust.ps1 -branch <feature branch name> -topleveldomain <test/prod> -username <admin email> -password <Admin password> -account <account name>
##############################################################################################################
#Arguments
param([string]$entityid,[string]$endpoint2)

#TLD Value to set for Test and Prod

if($entityid -eq $null) {
Write-Host "Please Enter the feature branch name and run the job again::"
}
if($endpoint -eq $null) {
Write-Host "Please Enter the account (Subdomain) name to which feature branch has to be added::"
}

# Get the Metadata URL
$FederationMetadataUrl = (Get-ADFSEndpoint  | where{$_.Protocol -eq "Federation Metadata"}).FullUrl.OriginalString

# Properties
$Identifier = "$entityid"
$encalgorithm = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"

# Check if the same Relying party trust exists, If Yes, Delete it before creating the new one
$rp = Get-ADFSRelyingPartyTrust -Identifier "https://$Identifier"
if ($rp) 
{
Remove-ADFSRelyingPartyTrust -TargetIdentifier "https://$Identifier"
Write-Host "Removing Relying Party Trust: $Identifier"
}

#Values
$apiendpoint = "$endpoint2"
$hostname = (Get-WmiObject win32_computersystem).DNSHostName

#SAML Endpoints
$endpoint1 = [System.Uri]"https://$Identifier/saml/acs"
$endpoint2 = [System.Uri]"https://$apiendpoint/sf/v3/Sessions/Acs"
$logouturl = ""

$samlEndpoint1 = New-ADFSSamlEndpoint -Protocol 'SAMLAssertionConsumer' -Uri $endpoint1 -Binding 'POST' -IsDefault $true -Index 1
$samlEndpoint2 = New-ADFSSamlEndpoint -Protocol 'SAMLAssertionConsumer' -Uri $endpoint2 -Binding 'POST' -IsDefault $false -Index 2
$samlEndpoint3 = New-ADFSSamlEndpoint -Protocol 'SAMLLogout' -Uri 'https://adfs3.sharefiletest.com/adfs/ls/?wa=wsignout1.0' -Binding 'POST'

#Transform Rules File
$TransformRules = "c:\scripts\TransformRules.txt"

#Issue Authorization Rules 
$authRules = '=> issue(Type = "http://schemas.microsoft.com/authorization/claims/permit", Value = "true");'
$rSet = New-ADFSClaimRuleSet –ClaimRule $authRules

#Creating the config file to store the ADFS values in C:\scripts folder
$configfile="C:\scripts\config_$branch.txt"
New-Item $configfile -type file -Force

# Adding Relying Party Trust
Try
{
Add-AdfsRelyingPartyTrust -Identifier "https://$Identifier" -Name $Name  -IssuanceTransformRulesFile $TransformRules -Enabled $true -SamlEndpoint @($samlEndpoint1, $samlEndpoint2, $samlEndpoint3) -SignatureAlgorithm $encalgorithm -ErrorAction Stop
Write-Host "Relying Party Trust added..."
}
Catch
{
$ErrorMessage = $_.Exception.Message
Write-Host $ErrorMessage
Remove-ADFSRelyingPartyTrust  -TargetIdentifier "https://$Identifier"
Remove-Item $configfile
exit $LastExitCode
}
#Set Relying Party Trust
Try
{
Set-AdfsRelyingPartyTrust -TargetIdentifier "https://$Identifier" –IssuanceAuthorizationRules $rSet.ClaimRulesString -ErrorAction Stop
Write-Host "Relying Party Trust configuration saved..."
}
Catch
{
$ErrorMessage = $_.Exception.Message
Write-Host $ErrorMessage
Remove-ADFSRelyingPartyTrust  -TargetIdentifier "https://$Identifier"
Remove-Item $configfile
exit $LastExitCode
}

# GET the AD FS token signing certificate to a CER File and Export the certificate To File (Base-64 Encoded)
$tokensigncert=Get-AdfsCertificate -CertificateType Token-Signing
$certBytes=$tokensigncert.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
[System.Convert]::ToBase64String($certBytes) > C:\temp\ADFSTokenSignBase-64.cer
$certBytesBase64 = [System.Convert]::ToBase64String($certBytes)

exit $LastExitCode