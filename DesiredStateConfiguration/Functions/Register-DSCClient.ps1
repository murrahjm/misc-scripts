<#
.Synopsis
Sets DSC client to pull configuration file from DSC Pull Server
.DESCRIPTION
This cmdlet configures the DSC Local Configuration Manager (LCM) to pull the configuration document in the format <computername>.mof from the DSC Pull Server.  Standardizes settings like auto-correct, update frequency, etc.  Also verified and/or requests a local machine certificate for DSC document encryption and copies public key certificate file to certificates share on Pull Server.
.PARAMETER Computername
The name of the client computer on which to configure the LCM.  computername will also be used to identify the name of the published MOF file.
.PARAMETER PullServer
The name of the server acting as DSC Pull server.  Can be the computername, FQDN, or dns alias, but device must be accessible and listening on port 8080.
.PARAMETER RegistrationKey
The shared key used to setup initial secure communication with the DSC Pull Server.  After the shared key is verified certificates are installed to secure further communication.
.PARAMETER Credential
A Credential object that has admin rights to the specified computername.  Will be used to run the LCM commands remotely on the target computer.
.EXAMPLE
Register-DSCClient -computername Server1.domain.com -pullserver dscpullserver -registrationKey 2422d38a-6848-467e-8b0f-75b0632dccf1

This example connects the server1.domain.com with the current session credentials, and configures the LCM to pull server1.domain.com.mof from the pull server and apply the configuration.
.EXAMPLE
$Configdata.Allnodes.NodeName | Register-DSCClient -credential $(get-credential) -pullserver dscpullserver -registrationKey 2422d38a-6848-467e-8b0f-75b0632dccf1

This example retrieves a list of computernames from a preconfigured Configurationdata hashtable and configures each computer to pull its respective configuration from the pull server.  The cmdlet prompts for credentials to be used in connecting to the computers.
#>
Function Register-DSCClient {
	Param(
		[Parameter(Mandatory=$True,ValueFromPipeline=$True)]
		[String[]]$Computername,

		[String]$PullServer,

		[guid]$RegistrationKey,

		[PSCredential]$Credential
	)
	BEGIN{
		$ErrorActionPreference = 'Stop'
		If ($PullServer.ToCharArray() -contains ':'){
			$Port = $PullServer.split(':')[1]
		} else {
			$Port = 8080
		}
		$PortCheckScriptblock = {
			Param($c,$p)
			write-verbose "Attempting connection to computer`:$c`tPort`:$p"
			$Socket = New-Object Net.Sockets.TcpClient
			$Socket.Connect($c,$p)
			If (! $Socket.Connected){
				Throw
			}else {
				$Socket.Close()
				$Socket.Dispose()
			}
		}
		Try {
			invoke-command -ScriptBlock $PortCheckScriptblock -ArgumentList $pullserver, $port
		} Catch {
			write-error "Unable to connect to pullserver $pullserver on port $port.  Check connection and try again"
			return
		}
	}
	PROCESS{
		Foreach ($Computer in $Computername){
			Try {
				$Session = New-PSSession -ComputerName $computer -Credential $Credential
				if ($Session -eq $Null){Throw}
				Write-Verbose "PSSession created for $computer"
				$PowershellVersionInfo = invoke-command -scriptblock {$PSVersionTable} -Session $Session
				write-verbose "Target computer $computer has powershell version $($PowershellVersionInfo.psversion)"
			} Catch {
				write-error "Error connecting to Target computer $computer.  Verify credentials and try again"
				continue
			}
			If ($PowershellVersionInfo.psversion.Major -lt 5){
				write-error "Powershell version $($PowershellVersionInfo.psversion.major) found, less than required version 5.0"
				return
			}
			Try {
				write-verbose "Checking TCP connection from $computer to $pullserver"
				Invoke-Command -ScriptBlock $PortCheckScriptblock -Session $Session -ArgumentList $Pullserver, $Port
			} Catch {
				If (! $Force){
				write-error "Unable to connect to pullserver address $PullServer`:$Port from target machine $computer.  Use -force to push this configuration anyway"
				return
				}
			}
			Try {
				$certinfo = Invoke-command -session $Session -ScriptBlock ${function:Get-DSCCertificate}
				$Thumbprint = $certinfo.thumbprint
				If (test-path "$($env:temp)\$computer.meta.mof"){Remove-Item "$($env:temp)\$computer.meta.mof" -force -confirm:$False}
				$Mof = PullmodewithAutoCorrect -PullServer $PullServer -Port $Port -RegistrationKey $RegistrationKey -ConfigName $Computer -certificateID $thumbprint -OutputPath $env:Temp | Rename-Item -NewName "$Computer.meta.mof" -Force -PassThru -confirm:$false
				write-verbose "Created configuration file $($mof.name) in directory $($Mof.directory.fullname)"
				Set-DscLocalConfigurationManager -Verbose -Path $Mof.Directory.Fullname -ComputerName $Computer -Credential $Credential		
			} Catch {
				write-error "Error setting configuration on $Computer.  Error is $_"
				return
			}
		}
	}
	END{}
}
#LCM Configuration to be used in Register-DSCClient cmdlet
[DscLocalConfigurationManager()]
Configuration PullmodewithAutoCorrect {
    Param(
        [String]$PullServer,
        [String]$Port,
        [guid]$RegistrationKey,
        [String]$ConfigName,
        [String]$CertificateID
    )
    Node localhost {
        Settings {
            RefreshMode = 'Pull'
            RebootNodeIfNeeded = $False
            ConfigurationMode = 'ApplyAndAutoCorrect'
            RefreshFrequencyMins = 30
            CertificateID = $CertificateID
        }
        ConfigurationRepositoryWeb domainPullServer {
            ServerURL = "https://$PullServer`:$Port/psdscpullserver.svc"
            RegistrationKey = $RegistrationKey
            ConfigurationNames = @($ConfigName)
        }
    }
}
