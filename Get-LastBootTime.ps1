Function Get-LastBootTime {
    Param(
        [Parameter(ValueFromPipeline=$True)]
        [String[]]$ComputerName,

        [PSCredential]$Credential,

        [switch]$Passthru
    )
    BEGIN{
        If ($Computername -eq $Null){
            write-verbose "No computername provided, running against local system"
        }
    }
    PROCESS{
        If ($ComputerName){
            Foreach ($Computer in $ComputerName){
                write-verbose "Processing Computer $Computer"
                If ($Credential){
                    $BootTime = Get-WMIObject Win32_OperatingSystem -ComputerName $Computer -Credential $credential | select -ExpandProperty lastbootuptime
                } else {
                    $BootTime = Get-WMIObject Win32_OperatingSystem -ComputerName $Computer | select -ExpandProperty lastbootuptime
                }
                If ($BootTime){
                    write-verbose "computer: $computer  Boottime:  $boottime"
                    If ($Passthru){
                        write-verbose "Passthru switch enabled, returning object with boottime and computername"
                        new-object psobject -Property @{
                            'ComputerName' = $Computer
                            'LastBootTime' = [System.Management.ManagementDateTimeConverter]::ToDateTime($BootTime)
                        }
                    } else {
                        [System.Management.ManagementDateTimeConverter]::ToDateTime($BootTime)
                    }
                }
            }
       } else {
                $BootTime = Get-WmiObject win32_OperatingSystem | select -ExpandProperty lastbootuptime
                [System.Management.ManagementDateTimeConverter]::ToDateTime($BootTime)
       }
    }
    END{}
}