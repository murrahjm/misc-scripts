Function Remove-KerberosTickets {
	Param (
		[Parameter(ValueFromPipeline=$True)]
		[String[]]$Computername = 'localhost',

		[System.Management.Automation.PSCredential]$Credential
	)
	BEGIN{
        $Scriptblock = {
            Function ConvertKerbSessionString{
                Param($SessionString)
                $LUID = [Convert]::ToString($SessionString.LogonID, 16)
                $LUID = '0x' + $LUID
                write-output $LUID
            }
            $SessionOutput = get-wmiobject -class Win32_LogonSession
            $Kerbsessions = foreach ($String in $SessionOutput){ConvertKerbSessionString $String}
            Foreach ($Session in $KerbSessions){
                write-verbose "Clearing ticket cache for logon session $session"
                c:\windows\system32\klist.exe -li $Session purge | out-null
            }
        }
    }
	PROCESS{
		Foreach ($Computer in $Computername){
            if ($Computer -ne 'localhost'){
                Try {
                    If ($Credential){
                        $PSSession = New-pssession -ComputerName $Computer -Credential $Credential -ea stop
                    } else {
                        $PSSession = New-PSSession -ComputerName $Computer -ea stop
                    }
                } Catch {
                    write-error "Unable to connect to $Computer via WSMAN"
                    return
                }
                invoke-command -ScriptBlock $Scriptblock -Session $PSSession
    		} else {
                invoke-command -ScriptBlock $Scriptblock
            }
	    }
    }
	END{}
}
