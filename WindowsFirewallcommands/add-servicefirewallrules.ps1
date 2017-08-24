Function add-serviceFirewallRules{
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [String[]]$ComputerName,

        [PSCredential]$Credential
    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
    }
    PROCESS{
        foreach ($computer in $ComputerName){
            write-verbose "$Functionname`:  Processing $Computer"
            If ($Credential){
                invoke-command -scriptblock {get-service} -Credential $Credential -ComputerName $computer |
                    out-gridview -PassThru |
                    ForEach-Object{
                        add-firewallrule -Computername $computer -Credential $Credential -ServiceName $_.name -confirm:$False
                    }
            } else {
                invoke-command -scriptblock {get-service} -ComputerName $computer |
                    out-gridview -PassThru -Title $Computer |
                    ForEach-Object{
                        add-firewallrule -Computername $computer -ServiceName $_.name -confirm:$False
                    }
            }
        }
    }
    END{}
}
