Function Get-KerberosTickets {
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
            If (!(test-path 'c:\windows\system32\klist.exe')){
                write-verbose "KList not found, Operating System not supported"
                return
            }
            $SessionOutput = get-wmiobject -class Win32_LogonSession
            $Kerbsessions = foreach ($String in $SessionOutput){ConvertKerbSessionString $String}
            Foreach ($Session in $KerbSessions){
                $tickets = (c:\windows\system32\klist.exe -li $Session tickets)
                If ($tickets -like "*Cached Tickets: (0)*"){
                    write-verbose "No tickets found for $session"
                } elseif ($Tickets -like "*klist failed*"){
                    write-verbose "Error retrieving tickets for $session"
                } else {
                    write-output $tickets
                }
            }
        }
    }
	PROCESS{
		Foreach ($Computer in $Computername){
            if ($Computer -ne 'localhost'){
                $Hostname = $Computer
                Try {
                    If ($Credential){
                        $PSSession = New-pssession -ComputerName $Computer -Credential $Credential -ea Stop
                    } else {
                        $PSSession = New-PSSession -ComputerName $Computer -ea Stop
                    }
                } Catch {
                    write-error "Unable to connect to $Computer via WSMAN"
                    return
                }
                $TicketData = invoke-command -ScriptBlock $Scriptblock -Session $PSSession
                remove-pssession $PSSession
    		} else {
                $Hostname = $env:Hostname
                $TicketData = invoke-command -ScriptBlock $Scriptblock
            }
            If ($TicketData){$output = convertfrom-KListTicket -inputString $TicketData}
            Foreach ($Ticket in $output){
                write-verbose "Adding hostname $hostname to ticket:"
                write-verbose "$($ticket | out-string)"
                add-member -InputObject $ticket -MemberType NoteProperty -Name ComputerName -Value $Hostname -PassThru
            }
	    }
    }
	END{}
}
Function ConvertFrom-KListTicket {
    Param(
        [Parameter(ValueFromPipeline=$True)]
        [String[]]$InputString
    )
    Begin{
$kliststringtemplate = @'

Current LogonId is 0:0x1becf1ed
Targeted LogonId is 0:0x3e7

Cached Tickets: (5)

#0>     Client: {Client*:server1$} @ domain.COM
        Server: {SPN:krbtgt/domain.COM} @ domain.COM
        KerbTicket Encryption Type: AES-256-CTS-HMAC-SHA1-96
        Ticket Flags 0x60a10000 -> forwardable forwarded renewable pre_authent name_canonicalize
        Start Time: {[datetime]StartTime:6/8/2017 9:48:38} (local)
        End Time:   {[datetime]EndTime:6/8/2017 19:34:43} (local)
        Renew Time: 6/15/2017 9:34:43 (local)
        Session Key Type: AES-256-CTS-HMAC-SHA1-96
        Cache Flags: 0x2 -> DELEGATION
        Kdc Called: DC03.domain.com

#1>     Client: {Client*:server1$} @ domain.COM
        Server: {SPN:krbtgt/domain.COM} @ domain.COM
        KerbTicket Encryption Type: AES-256-CTS-HMAC-SHA1-96
        Ticket Flags 0x40e10000 -> forwardable renewable initial pre_authent name_canonicalize
        Start Time: {[datetime]StartTime:6/8/2017 9:10:01} (local)
        End Time:   {[datetime]EndTime:10/30/2017 00:34:43} (local)
        Renew Time: 6/15/2017 9:34:43 (local)
        Session Key Type: AES-256-CTS-HMAC-SHA1-96
        Cache Flags: 0x1 -> PRIMARY
        Kdc Called: 

#2>	Client: {Client*:user1} @ domain.COM
	Server: {SPN:cifs/DC01.domain.com} @ domain.COM
	KerbTicket Encryption Type: AES-256-CTS-HMAC-SHA1-96
	Ticket Flags 0x40a50000 -> forwardable renewable pre_authent ok_as_delegate name_canonicalize
	Start Time: {[datetime]StartTime:6/8/2017 9:48:38} (local)
	End Time:   {[datetime]EndTime:6/8/2017 05:34:43} (local)
	Renew Time: 6/15/2017 9:34:43 (local)
	Session Key Type: AES-256-CTS-HMAC-SHA1-96
	Cache Flags: 0
	Kdc Called: DC03.domain.com

#3>	Client: {Client*:server1$} @ domain.COM
	Server: {SPN:LDAP/DC04.domain.com/domain.com} @ domain.COM
	KerbTicket Encryption Type: AES-256-CTS-HMAC-SHA1-96
	Ticket Flags 0x40a50000 -> forwardable renewable pre_authent ok_as_delegate name_canonicalize 
	Start Time: {[datetime]StartTime:6/8/2017 9:34:43} (local)
	End Time:   {[datetime]EndTime:6/9/2017 19:34:43} (local)
	Renew Time: 6/15/2017 9:34:43 (local)
	Session Key Type: AES-256-CTS-HMAC-SHA1-96
	Cache Flags: 0 
	Kdc Called: DC03.domain.com

Current LogonId is 0:0x1becf1ed
Targeted LogonId is 0:0x3e7

Cached Tickets: (5)

#0>     Client: {Client*:svc-app-pd01} @ domain.COM
        Server: {SPN:krbtgt/domain.COM} @ domain.COM
        KerbTicket Encryption Type: AES-256-CTS-HMAC-SHA1-96
        Ticket Flags 0x60a10000 -> forwardable forwarded renewable pre_authent name_canonicalize
        Start Time: {[datetime]StartTime:6/8/2017 9:48:38} (local)
        End Time:   {[datetime]EndTime:6/8/2017 19:34:43} (local)
        Renew Time: 6/15/2017 9:34:43 (local)
        Session Key Type: AES-256-CTS-HMAC-SHA1-96
        Cache Flags: 0x2 -> DELEGATION
        Kdc Called: DC03.domain.com

#1>     Client: {Client*:svc-account} @ domain.COM
        Server: {SPN:TERMSRV/domain.COM} @ domain.COM
        KerbTicket Encryption Type: AES-256-CTS-HMAC-SHA1-96
        Ticket Flags 0x40e10000 -> forwardable renewable initial pre_authent name_canonicalize
        Start Time: {[datetime]StartTime:6/8/2017 9:34:43} (local)
        End Time:   {[datetime]EndTime:6/8/2017 19:40:18} (local)
        Renew Time: 6/15/2017 9:34:43 (local)
        Session Key Type: AES-256-CTS-HMAC-SHA1-96
        Cache Flags: 0x1 -> PRIMARY
        Kdc Called: DC03.domain.com

'@
    }
    PROCESS {
        If ($InputString){[String]$CompleteString += $InputString | out-string}
    }
    END{
        ConvertFrom-String -InputObject $($CompleteString | out-string) -TemplateContent $kliststringtemplate
    }
}