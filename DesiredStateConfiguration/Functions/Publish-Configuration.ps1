<#
.Synopsis
Copies dsc configuration documents to DSC pull server for retrieval by client machines
.DESCRIPTION
This cmdlet takes a configuration document and moves it to the specified pull server for retrieval by the specified machine.  Also generates the appropriate checksum and naming information to fit with dsc environment standards.
.PARAMETER PullServer
The name of the server acting as DSC Pull server.  Can be the computername, FQDN, or dns alias, but device must be accessible and listening on port 8080.

.PARAMETER ConfigFile
The MOF file to publish to the specified pull server.  Can be either a fileinfo object or full path to the mof file.  The mof will be renamed to <computername>.mof while being moved to the pull server, but will be otherwise unmodified.

.PARAMETER Credential
A Credential object that has rights to copy configuration files to the pull server.
.EXAMPLE
Publish-Configuration -PullServer PSDSCPullServer.domain.com -configfile c:\temp\server1.mof

This example attempts to publish the file server1.mof to the specified pull server. Currently running credentials will be used as a credential object is not specified.
.EXAMPLE
Publish-Configuration -PullServer PSDSCPULLSERVER -configfile c:\temp\default.mof -credential $(get-credential)

This example will publish the file default.mof to the specified pull server.  The cmdlet will prompt for credentials to use in the operation.
.EXAMPLE
GCI c:\temp\*.mof | Publish-Configuration -pullserver PSDSCPULLSERVER

This example will retrieve all of the .mof files in the temp directory and publish them to the specified pull server.
#>
Function Publish-Configuration {
	[CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact='Low')]
	Param(
	
	[Parameter(Mandatory=$True)]
	[String]$PullServer,

	[Parameter(Mandatory=$True,ValueFromPipeline=$True)]
	[object]$ConfigFile,

	[PSCredential]$Credential

	)
	BEGIN{
		$ErrorActionPreference = 'Stop'
		Write-verbose "Validating access to $Pullserver"
		Try {
			$Hostname = $([system.net.dns]::GetHostByName($Pullserver)).HostName
			ValidatePullServer -computername $Hostname -credential $credential
			$Session = New-PSSession -ComputerName $Hostname -Credential $Credential
		} Catch {
			write-error "Unable to connect to DSC Pullserver $Pullserver.  Check servername and credentials and try again.  Error is $($_.message)"
			return
		}
		$DSCConfigurationFolder = 'C:\Program Files\WindowsPowerShell\DscService\Configuration'
		#
	}
	PROCESS{
		Foreach ($File in $ConfigFile){
			Try {
				$FileObject = get-childitem $File
				If (! $Fileobject.Extension -eq '.mof'){Throw}
			} Catch {
				Write-error "MOF file not found at location $File.  Check path and try again."
				Continue
			}
			$Destination = "$DSCConfigurationFolder\$($FileObject.Name)"
			If (Invoke-Command -ScriptBlock {param($path)test-path $Path} -Session $Session -ArgumentList $Destination){
				write-verbose "Destination file $Destination already exists, confirming overwrite"
				$ConfirmPreference = 'Low'
				$ConfirmMessage = 'Overwrite existing file'
			} else {
				$ConfirmPreference = 'High'
				$ConfirmMessage = 'Publish-Configuration'
			}
			If ($pscmdlet.ShouldProcess($PullServer,$ConfirmMessage)){
				Copy-Item $FileObject -Destination $DSCConfigurationFolder -ToSession $Session -Force -Confirm:$False
				Invoke-command -scriptblock {param($Path)New-DscChecksum -Path $Path -OutPath $(split-path $Path -Parent) -Force} -Session $Session -ArgumentList $Destination
			}
		}
	}
	END{
		$Session | Remove-PSSession -confirm:$False
	}
}
