Function ValidatePullServer {
	param($Computername, [pscredential]$Credential)
    $Hostname = $([system.net.dns]::GetHostByName($Computername)).HostName
	$DSCConfigurationFolder = 'C:\Program Files\WindowsPowerShell\DscService\Configuration'
	$DSCResourceFolder = 'C:\Program Files\WindowsPowerShell\DscService\Modules'
	$DSCWebFolder = 'C:\inetpub\wwwroot\PSDSCPullServer'
	$Socket = New-Object Net.Sockets.TcpClient
	If ($Hostname.ToCharArray() -contains ':'){
		$Port = $Hostname.split(':')[1]
	} else {
		$Port = 8080
	}
	Try {
		$Socket.Connect($Hostname, $Port)
		If (! $Socket.Connected){
			Throw
		}else {
			$Socket.Close()
			$Socket.Dispose()
		}
	}Catch {
		Write-error "Unable to connect to $Hostname on port $Port.  Exiting script"
		return
	}
	Try {
		If ($Credential){
			$Session = New-PSSession -ComputerName $Hostname -Credential $Credential
		} else {
			$Session = New-PSSession -ComputerName $Hostname
		}
	} Catch {
		Write-error "Unable to open remote session to $Hostname.  Check server and credentials.  Exiting script"
		return
	}
	Try {
		$dscFileStatus = Invoke-command {Param($Path)test-path $path} -session $Session -ArgumentList $DSCConfigurationFolder
		If ($dscFileStatus -eq $False){Throw}
		$dscWebFileStatus = Invoke-command {Param($Path)Test-Path $Path} -Session $Session -ArgumentList "$DSCWebFolder\psdscpullserver.svc"
		If ($dscWebFileStatus -eq $False){Throw}
	} Catch {
		Write-error "DSC files not found on $Hostname.  verify configuration and try again.  Exiting script"
		return
	}
	Remove-PSSession $Session

}
function CreateZipFromPSModulePath
{
    param($ListModuleNames, $Destination, [switch]$Passthru)

    # Move all required  modules from powershell module path to a temp folder and package them
    if ([string]::IsNullOrEmpty($ListModuleNames))
    {
        write-verbose "No additional modules are specified to be packaged." 
    }
    
    foreach ($module in $ListModuleNames)
    {
        $allVersions = Get-Module -Name $module -ListAvailable        
        # Package all versions of the module
        foreach ($moduleVersion in $allVersions)
        {
            $name   = $moduleVersion.Name
            $source = "$Destination\$name"
            # Create package zip
            $path    = $moduleVersion.ModuleBase
            $version = $moduleVersion.Version.ToString()
            Write-verbose "Zipping $name ($version)"
            Compress-Archive -Path "$path\*" -DestinationPath "$source.zip" -Force 
            $newName = "$Destination\$name" + "_" + "$version" + ".zip"
            # Rename the module folder to contain the version info.
            if (Test-Path $newName)
            {
                Remove-Item $newName -Recurse -Force 
            }
            Rename-Item -Path "$source.zip" -NewName $newName -Force
			If ($Passthru){$newName}
        } 
    }   

}


# Deploy modules to the Pull server repository.
function PublishModules
{
    param($Source, $PullServerSession)
    $moduleRepository = "C:\Program Files\WindowsPowerShell\DscService\Modules"
    Write-verbose "Copying modules and checksums to [$moduleRepository]."
    Copy-Item "$Source*" -Destination $moduleRepository -Tosession $PullServerSession -Force
    
}

#retrieves dsc encryption certificate from local machine store.  if a certificate is not found, one is requested from the enterprise PKI.
#This assumes there is an enterprise PKI with a template named 'DSC Encryption'
Function Get-DSCCertificate {
    $DSCCert = $(gci cert:\localmachine\my).where{$_.extensions.oid.value -eq '1.3.6.1.4.1.311.21.7'}.where{$_.extensions.Format(1) -like "*DSC Encryption*"} | Sort-Object -Property notAfter | select -First 1
    If ($DSCCert.count -eq 0){
        #this was hardcoded, needs to be updated for new environment, or, ideally, dynamically retrieved from the domain
        $CertRequest = get-certificate -template DSCEncryption -certstoreLocation cert:\LocalMachine\My -Url ldap:///CN=<CA Name>
        Get-DSCCertificate
    } else {
        $LocalCertFile = $dsccert | Export-Certificate -Type CERT -FilePath "$env:temp\certfile.cer" -Force
        $CertFileData = $LocalCertFile | get-content -Encoding Byte
        new-object PSObject -Property @{
            Thumbprint = $DSCCert.Thumbprint
            CertFileData = $CertFileData
        }
    }
}
