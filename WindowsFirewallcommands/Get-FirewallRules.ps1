Function Get-FirewallRules {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1)]
        [ValidateScript({test-connection -computername $_ -count 1})]
        [String]$Computername,

        [PSCredential]$Credential

    )
    $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
    $ErrorActionPreference = 'Stop'
    write-verbose "$FunctionName`:  Validating access to $ComputerName"
    If ($Credential){
        If (! (Test-access -computername $computerName -credential $Credential -quiet)){
            write-error "Invalid credentials or access denied to $computername" -ea continue
            return
        }
    } else {
        If (!(Test-Access -computername $computerName -quiet)){
            write-error "Invalid credentials or access denied to $computername" -ea continue
            return
        }
    }
    write-verbose "$FunctionName`:  Attempting WSMAN connection to $computername"
    Try {
        If ($Credential){
            $Session = New-PSSession -ComputerName $computername -Credential $Credential
        } else {
            $Session = New-PSSession -ComputerName $computername
        }
        If ($Session) {Write-verbose "Connected to: $computername via WSMAN"} else {Throw}
    } Catch {
        write-error "Unable to connect to $computername" -ea Continue
        return
    }
    $return = invoke-command -ScriptBlock {$fw = New-object -comObject HNetCfg.FwPolicy2;$fw.rules} -Session $Session
    write-verbose "$FunctionName`:  Removing session $Session"
    Remove-PSSession $Session -whatif:$False
    if ($Return) {
        If ($Return.length -le 1){
            Write-Verbose "$FunctionName`:  No rules found"
        } else {
            Foreach ($Rule in $Return){
                #parse each rule for formatting and convert code numbers to text descriptions
                $properties = [ordered]@{
                    Name = $Rule.Name
                    Description = $Rule.Description
                    ApplicationName = $Rule.ApplicationName
                    ServiceName = $Rule.ServiceName
                    Protocol = $(
                        Switch ($Rule.Protocol){
                            '1'  {'ICMPv4'}
                            '2'  {'IGMp'}
                            '17' {'UDP'}
                            '6'  {'TCP'}
                            '58' {'ICMPv6'}
                            '47' {'GRE'}
                            '41' {'IPv6'}
                        }
                    )
                    LocalPorts = $Rule.LocalPorts
                    RemotePorts = $Rule.RemotePorts
                    LocalAddresses = $Rule.LocalAddresses
                    RemoteAddresses = $Rule.RemoteAddresses
                    Direction = $(
                        Switch ($Rule.Direction){
                            '1' {'In'}
                            '2' {'Out'}
                        }
                    )
                    Enabled = $(
                        Switch ($Rule.Enabled){
                            $True {'yes'}
                            $False {'no'}
                        }
                    )
                    Action = $(
                        Switch ($Rule.Action){
                            '0' {'Block'}
                            '1' {'Allow'}
                        }
                    )
                }
                $output = new-object psobject -property $Properties
                #filter rules to only output enabled rules and inbound rules
                If ($($Output.Enabled -eq 'yes') -and $($output.Direction -eq 'In')) {
                    $output
                }
            }
        }
    } else {
        write-error "No firewall rules found.  Check firewall state" -ea Continue
    }
}
