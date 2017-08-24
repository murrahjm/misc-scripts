Function Copy-FirewallRules{
    [cmdletbinding(DefaultParameterSetName='NoCreds',SupportsShouldProcess=$True,ConfirmImpact='High')]
        Param(
        [Parameter(Mandatory=$True,Position=1)]
        [Parameter(ParameterSetName='NoCreds')]
        [Parameter(ParameterSetName='SingleCred')]
        [Parameter(ParameterSetName='DoubleCred')]
        [ValidateScript({test-connection -computername $_ -count 1})]
        [String]$Source,

        [Parameter(Mandatory=$True,Position=2)]
        [Parameter(ParameterSetName='NoCreds')]
        [Parameter(ParameterSetName='SingleCred')]
        [Parameter(ParameterSetName='DoubleCred')]
        [ValidateScript({test-connection -computername $_ -count 1})]
        [String]$Destination,

        [Parameter(Mandatory=$True,ParameterSetName='SingleCred')]
        [PSCredential]$Credential,

        [Parameter(Mandatory=$True,ParameterSetName='DoubleCred')]
        [PSCredential]$SourceCredential,

        [Parameter(Mandatory=$True,ParameterSetName='DoubleCred')]
        [pscredential]$DestinationCredential
    )
    $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
    Try {
        If ($Credential){
            If (!(Test-access -computername $source -credential $Credential -quiet)){
                throw "Invalid Credentials or Access Denied to $Source"
            }
            If (!(Test-access -computername $destination -credential $Credential -quiet)){
                throw "Invalid Credentials or Access Denied to $destination"
            }
            $SourceRules = Get-FirewallRules -Computername $Source -Credential $Credential
            $DestinationRules = Get-FirewallRules -Computername $Destination -Credential $Credential
        } elseif ($SourceCredential -and $DestinationCredential){
            If (!(Test-access -computername $source -credential $SourceCredential -quiet)){
                throw "Invalid Credentials or Access Denied to $Source"
            }
            If (!(Test-access -computername $destination -credential $DestinationCredential -quiet)){
                throw "Invalid Credentials or Access Denied to $destination"
            }
            $SourceRules = Get-FirewallRules -computername $Source -Credential $SourceCredential
            $DestinationRules = Get-FirewallRules -Computername $Destination -Credential $DestinationCredential
        } else {
            If (!(Test-access -computername $source -quiet)){
                throw "Invalid Credentials or Access Denied to $Source"
            }
            If (!(Test-access -computername $destination -quiet)){
                throw "Invalid Credentials or Access Denied to $destination"
            }
            $SourceRules = Get-Firewallrules -Computername $Source
            $DestinationRules = Get-FirewallRules -Computername $Destination
        }
        If ($SourceRules -eq $Null){Throw "No rules found on Source Server"}
        If ($DestinationRules -eq $Null){Throw "No rules found on Destination Server"}
    } Catch {
        write-error "Error Retrieving firewall rules.  Error message:  $_"
        return
    }
    write-verbose "$FunctionName`:  Current ruleset retrieved for Source: $Source and Destination: $Destination"
    $RulesToCreate = foreach ($sourcerule in $Sourcerules){
        write-verbose "$FunctionName`:  Looking for source rule $($sourcerule.name) on destination"
        #iterate through each rule on the source server
        #find any rules in the destination that match the source rule.
        $match = $Destinationrules | where-object{Compare-Rules -reference $_ -difference $sourcerule}
        #if no rules were found on the destination server to match the current source rule
        # add it to the list of rules to be created on the destination
        if ($match -eq $Null){
            write-verbose "$FunctionName`:  Source rule $($Sourcerule.name) not found on destination, adding to Create list"
            $sourcerule
        }
    }
    If ($RulesToCreate -eq $Null){
        write-output "No unique rules found to copy"
        return
    } else {
        write-verbose "$FunctionName`:  Difference rules compiled:"
        foreach ($Rule in $RulesToCreate){write-verbose "`t Name: $($Rule.Name)"}
        Foreach ($Rule in $RulesToCreate){
            If ($PSCmdlet.ShouldProcess($destination, "Create Firewall Rule: $($Rule.Name)")){
                If ($Credential){
                    Add-firewallrule -computername $destination -credential $Credential -Rule $Rule -confirm:$False
                } elseif ($DestinationCredential){
                    Add-firewallrule -computername $destination -credential $DestinationCredential -Rule $Rule -confirm:$False
                } else {
                    Add-Firewallrule -computername $destination -Rule $Rule -confirm:$False
                }
            }
        }
    }
}
Function Compare-Rules {
    Param(
        $Reference,
        $Difference
    )
    $propertylist = @('Name','Description','ApplicationName','ServiceName','Protocol','LocalPorts','RemotePorts','LocalAddress','RemoteAddresses','Direction','Enabled','Action')
    $Result=compare-object -ReferenceObject $Reference -DifferenceObject $Difference -property $Propertylist
    If ($Result){return $False} else {return $True}
}