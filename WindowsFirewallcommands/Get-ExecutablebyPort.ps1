Function Get-ExecutablebyPort {
[cmdletbinding()]
    Param (
        [String]$Port,
        [String]$Computername,
        [PSCredential]$Credential
    )
    If ($Credential){
        $Session = New-PSSession -ComputerName $Computername -Credential $Credential
    } else {
        $Session = New-PSSession -ComputerName $Computername
    }
    If ($Session){
        $Netstatoutput = invoke-command -Session $Session -ScriptBlock {netstat -ano}
        write-verbose "netstat retrieved, looking for port $port listening entry"
        $NetstatString = $netstatoutput | ?{$_ -like "*$Port*LISTENING*"}
        If ($NetstatString){
            write-verbose "netstat entry found:  $netstatstring"
            $processID = $netstatstring.split(' ')[-1]
            write-verbose "associated PID:  $processID"
            $Path = invoke-command -session $Session -ScriptBlock {get-process -pid $args[0] | select -ExpandProperty Path} -ArgumentList $ProcessID
            write-verbose "Path for PID $processID`:  $path"
            if ($Path){return $Path}
        } else {
            Write-Warning "Port $port not found in netstat output.  Process may be stop"
        }
        Remove-PSSession $Session
    } else {
        write-error "unable to connect remotely to $computername"
        return
    }
}
