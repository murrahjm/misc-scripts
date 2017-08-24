<#
.Synopsis
Copies dsc Resource documents to DSC pull server for retrieval by client machines
.DESCRIPTION
This cmdlet takes a Resource document and moves it to the specified pull server for retrieval by client machines.  Also creates the necessary zip file in the required format for automatic retrieval.
.PARAMETER PullServer
The name of the server acting as DSC Pull server.  Can be the computername, FQDN, or dns alias, but device must be accessible and listening on port 8080.

.PARAMETER Resource
The DSC Resource to publish to the specified pull server.  Can be either the root folder of the dsc resource or the psd1 file for the resource.  A basic check of the folder structure will be done validate that the folder is a proper DSC resource.  The folder will be modified and zipped up in the correct format for use by clients when downloading from the dsc pull server.

.PARAMETER Credential
A Credential object that has rights to copy Resource files to the pull server.
.EXAMPLE
Publish-Resource -PullServer PSDSCPullServer.domain.com -Resource c:\temp\xPSDesiredStateConfiguration

This example attempts to publish the dsc resource xPSDesiredStateConfiguration to the specified pull server.  Currently running credentials will be used as a credential object is not specified.
.EXAMPLE
Publish-Resource -PullServer PSDSCPULLSERVER -resource c:\temp\xPSDesiredStateConfiguration\3.10.0.0\xPSDesiredStateConfiguration.psd1 -ComputerName Server1 -credential $(get-credential)

This example will publish the resource xPSDesiredStateConfiguration to the specified pull server.  The cmdlet will attempt to identify the entire resource folder based on the provided psd1 file.  If the resource structure cannot be validated the cmdlet will return an error.  The cmdlet will prompt for credentials to use in the operation.
.EXAMPLE
GCI c:\temp\DSCResources\ | foreach-object {Publish-Resource -pullserver PSDSCPULLSERVER -Resource $_}

This example will retrieve all of the DSC Resources in the temp directory and publish them to the specified pull server.
#>
Function Publish-Resource {
	[CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact='Low')]
	Param(
	
	[Parameter(Mandatory=$True)]
	[String]$PullServer,

	[Parameter(Mandatory=$True,ValueFromPipeline=$True)]
	[object[]]$Resource,

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
	}
	PROCESS{
        Foreach ($folder in $Resource){
            write-verbose "Beginning processing $Folder"
			Try {
				If ($Folder.Fullname){
					$Module = get-item $Folder.fullname
				} else {
					$Module = get-item $Folder
				}
			} Catch {
				Write-Error "Unable to validate path $Folder.  Error is $($_.message)"
			}
			write-verbose "Processing DSC Module folder $($Module.FullName)"
            $ZipFileName = CreateZipFromPSModulePath -ListModuleNames $Module.FullName -Destination $env:TEMP -Passthru
			write-verbose "Created zip file $zipfilename"
			New-DscChecksum -Path $ZipFileName -Force
            PublishModules -Source $ZipFileName -PullServerSession $Session
        }
	}
	END{
		$Session | Remove-PSSession -confirm:$False
	}
}
