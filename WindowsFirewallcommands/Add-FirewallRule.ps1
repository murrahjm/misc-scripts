Function Add-FirewallRule {
    [cmdletbinding(DefaultParameterSetName='byPort',SupportsShouldProcess=$True,ConfirmImpact='High')]
    Param(
        [Parameter(Mandatory=$True,Position=1)]
        [ValidateScript({test-connection -computername $_ -count 1})]
        [String[]]$Computername,

        [PSCredential]$Credential,

        [Parameter(Mandatory=$True,ParameterSetName='byPort')]
        [String]$Name,

        [Parameter(Mandatory=$True,ParameterSetName='byPort')]
        [string[]]$Ports,

        [Parameter(Mandatory=$True,ParameterSetName='byService')]
        [String]$ServiceName,

        [Parameter(Mandatory=$True,ParameterSetName='byProgram')]
        [String]$ProgramPath,

        [Parameter(Mandatory=$True,ParameterSetName='byPort')]
        [ValidateSet('TCP','UDP')]
        [String]$Protocol='TCP',

        [Parameter(ParameterSetName='byInputObject')]
        [Object]$Rule
    )
    $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
    $ErrorActionPreference = 'Stop'
    Switch ($PSCmdlet.ParameterSetName) {
        'byPort' {
            $PortString = $ports -join ','
            $portstring = $Portstring.replace(' ','').replace(',,',',')
            $CMDString = "netsh advfirewall firewall add rule `
                            name=`"$Name`" `
                            localport=`"$portstring`" `
                            dir=in `
                            action=allow `
                            enable=yes `
                            profile=any `
                            protocol=$Protocol"
        }
        'byService' {
            $Name = $ServiceName
            $CMDString = "netsh advfirewall firewall add rule `
                            name=`"$ServiceName`" `
                            service=`"$ServiceName`" `
                            dir=in `
                            action=allow `
                            enable=yes `
                            profile=any"
        }
        'byProgram' {
            $ProgramName = split-path $programpath -Leaf
            $Name = $ProgramName
            $CMDString = "netsh advfirewall firewall add rule `
                            name=`"$programName`" `
                            program=`"$programpath`" `
                            dir=in `
                            action=allow `
                            enable=yes `
                            profile=any"
        }
        'byInputObject' {
            $CMDString = "netsh advfirewall firewall add rule "
            If ($Rule.Name){
                $CMDString += "name=`"$($Rule.Name)`" "
                $Name = $Rule.name
            }
            If ($Rule.Description){$cmdstring += "description=`"$($Rule.Description)`" "}
            If ($Rule.ApplicationName){$cmdstring += "program=`"$($Rule.ApplicationName)`" "}
            If ($Rule.ServiceName){$cmdstring += "service=`"$($Rule.ServiceName)`" "}
            If ($Rule.Protocol){$cmdstring += "protocol=`"$($Rule.Protocol)`" "}
            If ($Rule.LocalPorts){$cmdstring += "localport=`"$($Rule.LocalPorts)`" "}
            If ($Rule.RemotePorts){$cmdstring += "remoteport=`"$($Rule.RemotePorts)`" "}
            If ($Rule.Action){$cmdstring += "action=`"$($Rule.Action)`" "}
            If ($Rule.LocalAddresses){$cmdstring += "localip=`"$($Rule.LocalAddresses)`" "}
            If ($Rule.RemoteAddresses){$cmdstring += "remoteip=`"$($Rule.RemoteAddresses)`" "}
            $cmdstring += "direction=in enable=yes profile=any"
        }
    }
    $CMDString = $CMDString -replace "`n|`r|  ",''
    $cmdstring = $CMDString -replace '\=\"\*','="any'
    Foreach ($Computer in $Computername){
        write-verbose "$FunctionName`:  Beginning computer $Computer"
        If ($Credential){
            If (! (Test-access -computername $computer -credential $Credential -quiet)){
                write-error "Invalid credentials or access denied to $computer" -ea continue
                continue
            }
        } else {
            If (!(Test-Access -computername $computer -quiet)){
                write-error "Invalid credentials or access denied to $computer" -ea continue
                write-verbose "!!!"
                continue
            }
        }
        write-verbose "$FunctionName`:  executing:  $cmdstring"
        If ($PSCmdlet.ShouldProcess($computer, "Create Firewall Rule: $Name")){
            Try {
                If ($Credential){
                    $Session = New-PSSession -ComputerName $Computer -Credential $Credential
                } else {
                    $Session = New-PSSession -ComputerName $Computer
                }
                If ($Session) {Write-verbose "Connected to: $Computer"} else {Throw}
            } Catch {
                write-error "Unable to connect to $computer"
                return
            }
            $Scriptblock = [scriptblock]::Create($cmdstring)
            $return = invoke-command -ScriptBlock $Scriptblock -Session $Session
            if ($return -ne 'Ok.') {
                write-error "Error running command.  error code:  $return"
            }
            Remove-PSSession $Session -whatif:$False
        }
    }
}
