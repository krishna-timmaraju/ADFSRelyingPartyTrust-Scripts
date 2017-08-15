#PowerShell script to delete the Relying Party Trust in ADFS3 Server
# Accepts the feature branch name as the parameter (used to name the Relying Party in ADFS)
param([string]$branch, [string]$tld)

#TLD Value to set for Test
if(($tld -eq 'test') -Or ($tld -eq $null)) {
$domain = "sharefiletest.com"
$apitld = "sf-apitest.com"
}

#TLD Value to set for Test
if(($tld -eq 'stage')) {
$domain = "sharefilestaging.com"
$apitld = "sf-apistaging.com"
}

$Identifier = "$branch.$domain"

Try
{
$rp = Get-ADFSRelyingPartyTrust -Identifier "https://$Identifier"
if ($rp) 
{
Remove-ADFSRelyingPartyTrust -TargetIdentifier "https://$Identifier"
Write-Host "Removing Relying Party Trust: $Identifier"
}
}
Catch
{
$ErrorMessage = $_.Exception.Message
Write-Host $ErrorMessage
exit $LastExitCode
}

exit $LastExitCode