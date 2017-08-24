Function Compare-FirewallRules{
    [cmdletbinding(DefaultParameterSetName='NoCreds',SupportsShouldProcess=$True,ConfirmImpact='High')]
        Param(
        [Parameter(Mandatory=$True,Position=1)]
        [Parameter(ParameterSetName='NoCreds')]
        [Parameter(ParameterSetName='SingleCred')]
        [Parameter(ParameterSetName='DoubleCred')]
        [ValidateScript({test-connection -computername $_ -count 1})]
        [String]$Server1,

        [Parameter(Mandatory=$True,Position=2)]
        [Parameter(ParameterSetName='NoCreds')]
        [Parameter(ParameterSetName='SingleCred')]
        [Parameter(ParameterSetName='DoubleCred')]
        [ValidateScript({test-connection -computername $_ -count 1})]
        [String]$Server2,

        [Parameter(Mandatory=$True,ParameterSetName='SingleCred')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential,

        [Parameter(Mandatory=$True,ParameterSetName='DoubleCred')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Server1Credential,

        [Parameter(Mandatory=$True,ParameterSetName='DoubleCred')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Server2Credential
    )
    $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
    Try {
        If ($Credential){
            If (!(Test-access -computername $Server1 -credential $Credential -quiet)){
                throw "Invalid Credentials or Access Denied to $Server1"
            }
            If (!(Test-access -computername $Server2 -credential $Credential -quiet)){
                throw "Invalid Credentials or Access Denied to $Server2"
            }
            $Server1Rules = Get-FirewallRules -Computername $Server1 -Credential $Credential
            $Server2Rules = Get-FirewallRules -Computername $Server2 -Credential $Credential
        } elseif ($Server1Credential -and $Server2Credential){
            If (!(Test-access -computername $Server1 -credential $Server1Credential -quiet)){
                throw "Invalid Credentials or Access Denied to $Server1"
            }
            If (!(Test-access -computername $Server2 -credential $Server2Credential -quiet)){
                throw "Invalid Credentials or Access Denied to $Server2"
            }
            $Server1Rules = Get-FirewallRules -computername $Server1 -Credential $Server1Credential
            $Server2Rules = Get-FirewallRules -Computername $Server2 -Credential $Server2Credential
        } else {
            If (!(Test-access -computername $Server1 -quiet)){
                throw "Invalid Credentials or Access Denied to $Server1"
            }
            If (!(Test-access -computername $Server2 -quiet)){
                throw "Invalid Credentials or Access Denied to $Server2"
            }
            $Server1Rules = Get-Firewallrules -Computername $Server1
            $Server2Rules = Get-FirewallRules -Computername $Server2
        }
        If ($Server1Rules -eq $Null){Throw "No rules found on Server1 Server"}
        If ($Server2Rules -eq $Null){Throw "No rules found on Server2 Server"}
    } Catch {
        write-error "Error Retrieving firewall rules.  Error message:  $_"
        return
    }
    write-verbose "$FunctionName`:  Current ruleset retrieved for Server1: $Server1 and Server2: $Server2"
    $DifferenceRules = foreach ($Server1rule in $Server1rules){
        write-verbose "$FunctionName`:  Looking for Server1 rule $($Server1rule.name) on Server2"
        #iterate through each rule on the Server1 server
        #find any rules in the Server2 that match the Server1 rule.
        $match = $Server2rules | where-object{Compare-Rules -reference $_ -difference $Server1rule}
        #if no rules were found on the Server2 server to match the current Server1 rule
        # add it to the list of rules to be created on the Server2
        if ($match -eq $Null){
            write-verbose "$FunctionName`:  Server1 rule $($Server1rule.name) not found on Server2, adding to Create list"
            $Server1rule
        }
    }
    If ($DifferenceRules -eq $Null){
        write-output "No unique rules found to copy"
        return
    } else {
        write-verbose "$FunctionName`:  Difference rules compiled:"
        foreach ($Rule in $DifferenceRules){
            Write-Output $Rule
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