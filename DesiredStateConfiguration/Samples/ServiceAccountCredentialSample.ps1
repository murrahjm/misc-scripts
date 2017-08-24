<#
Sample script to illustrate the use of credentials in a configuration document.  Credential objects are passed through parameters to the configuration.  note that multiple credential
objects are supported.  Get-DSCCertificate is a helper function that will retreive the DSC encryption certificate details from a specified machine.  If the specified machine does not
have a dsc encryption certificate it will request one from the enterprise PKI, then return the details.  The return object has a thumbprint value, then the actual certificate file
encoded in a byte array.  Both the thumbprint and certificate file are needed for encrypting a mof.

The attempted use of this sample code would be to handle service account password changes.  the xADUser resource would change the password of the account in Active Directory, 
and the xService resource would set the service logon account and password.  This mostly works, however the xService Test function only checks for a change in the logon username.
If only the password changes for the service account the Set method will never be triggered, so the password in the service configuration would not be updated.  All the rest of the
code around encrypting credentials, etc. works, however.
#>

Param(
    $Computer,
    $credential = $Credential
)
configuration DSCCredentialTest {
    param(
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()]
        [PsCredential]$ServiceAccountCredential,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()]
        [PsCredential]$ADCredential

    )
    Import-DscResource �ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration' -ModuleVersion '5.1.0.0'
    Import-DSCResource -ModuleName 'xActiveDirectory' -ModuleVersion '2.15.0.0'

    node $Allnodes.NodeName
    {
        xService SQLServer {
            Name = 'MSSQL'
            Credential = $ServiceAccountCredential
        }
        #parse serviceaccountcredential object to extract domainname and username for use in xADUser
        If ($ServiceAccountCredential.username -like "*\*"){
            $ServiceAccountUserName = $ServiceAccountCredential.username.split('\')[1]
            $ServiceAccountDomainName = $ServiceAccountCredential.username.split('\')[0]
        } elseif ($ServiceAccountCredential.username -like "*@*"){
            $ServiceAccountUserName = $ServiceAccountCredential.username.split('@')[0]
            $ServiceAccountDomainName = $ServiceAccountCredential.username.split('@')[1]
        }
        xADUser ServiceAccount {
            UserName = $ServiceAccountUserName
            DomainName = $ServiceAccountDomainName
            Password = $ServiceAccountCredential
            PsDscRunAsCredential = $ADCredential
        }
    }
}
#get-dsccertificate retrieves the thumbprint and exported certificate file from the target machine.
$certificateData = Invoke-Command -ComputerName $Computer -Credential $credential -ScriptBlock ${function:Get-DSCCertificate}
$Thumbprint = $certificateData.Thumbprint

#set-content used to re-inflate the target machine certificate file into a local certificate file for use in the credential encryption
$certificateData.CertFileData | set-content -Path "$env:temp\$computer.cer" -encoding Byte
$LocalCertfile = gci "$env:temp\$computer.cer"

#encrypting credentials in a configuration requires certain values to be present in a configuration data object.  Rather than reference an external file, this can be built
#inline using the values retreived from the target machine.
$configdata = @{
    AllNodes = @(
        @{
            NodeName = $Computer
            CertificateFile = $LocalCertfile.FullName
            Thumbprint = $Thumbprint
            PSDscAllowDomainUser = $true
        }
    )
}

#register-dscclient is run in case the encryption certificate has changed since the LCM was last updated on the target node.
Register-DSCClient -Computername $Computer -PullServer dscpullserver.domain.com -RegistrationKey 24e1ba9c-8f42-4a1d-8258-85c87c1ef041 -Credential $credential

#All the encryption of credentials happens here, on the authoring node.
$Mof = DSCCredentialTest -ConfigurationData $ConfigData -OutputPath $env:temp -ADCredential domain\serveradmin -ServiceAccountCredential domain\serviceaccount

#"publishing" a configuration is really just copying it to the pull server and creating a checksum file for it.  Note that the pull server doesn't have to know anything about
#the encryption certificate.  It's simply a delivery vehicle for the already encrypted mof file
Publish-Configuration -PullServer dscpullserver.domain.com -ConfigFile $mof -Credential $credential

#After updating the config on the pull server, update-dscconfiguration is run on the target machine to retrieve it without having to wait.  Not strictly necessary but
#useful for troubleshooting.  verbose  and wait switches present all the output on screen to identify which resources run or fail
invoke-command -computername $computer -credential $Credential -ScriptBlock {Update-DscConfiguration -Verbose -wait}