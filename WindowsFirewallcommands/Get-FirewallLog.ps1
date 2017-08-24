Function Get-FirewallLog {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True,Position=1)]
        [ValidateScript({test-connection -computername $_ -count 1})]
        [String]$Computername,

        [PSCredential]$Credential,

        [ValidateSet('SMB','WSMAN')]
        [String]$ConnectionMethod='SMB'

    )
    $ErrorActionPreference = 'Stop'
    $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
$FirewallLogTemplate = @'
#Version: 1.5
#Software: Microsoft Windows Firewall
#Time Format: Local
#Fields: date time action protocol src-ip dst-ip src-port dst-port size tcpflags tcpsyn tcpack tcpwin icmptype icmpcode info path

{[datetime]TimeStamp*:2016-05-05 07:30:07} {Action:DROP} {Protocol:UDP} {SourceIP:10.96.105.243} {DestIP:224.0.0.252} {SourcePort:61782} {DestPort:5355} 0 - - - - - - - RECEIVE
{[datetime]TimeStamp*:2016-05-05 07:30:21} {Action:DROP} {Protocol:TCP} {SourceIP:10.98.32.233} {DestIP:10.96.105.191} {SourcePort:60164} {DestPort:1434} 40 - - - - - - - RECEIVE
{[datetime]TimeStamp*:2017-04-07 10:45:43} {Action:DROP} {Protocol:ICMP} {SourceIP:10.32.72.58} {DestIP:10.96.101.190} {SourcePort:-} {DestPort:-} 84 - - - - 0 0 - RECEIVE
{[datetime]TimeStamp*:2017-04-07 10:45:43} {Action:DROP} {Protocol:ICMP} {SourceIP:10.32.72.58} {DestIP:10.96.101.190} {SourcePort:-} {DestPort:-} 84 - - - - 0 0 - RECEIVE
'@
    Foreach ($Computer in $Computername){
        write-verbose "$FunctionName`:  Validating access to $Computer"
        If ($Credential){
            If (! (Test-access -computername $computer -credential $Credential -quiet)){
                write-error "Invalid credentials or access denied to $computer" -ea continue
                continue
            }
        } else {
            If (!(Test-Access -computername $computer -quiet)){
                write-error "Invalid credentials or access denied to $computer" -ea continue
                continue
            }
        }
        #Attempt to retrieve firewall log contents through an SMB connection to the remote filesystem
        If ($ConnectionMethod -eq 'SMB'){
            write-verbose "$FunctionName`:  Attempting SMB connection to $computer"
            Try{
                If ($Credential){
                    $PSDrive = New-PSDrive -name $Computer -PSProvider FileSystem -Root "\\$Computer\c$" -Description $Computer -Credential $Credential
                } else {
                    $PSDrive = New-PSDrive -name $Computer -PSProvider FileSystem -Root "\\$Computer\c$" -Description $Computer
                }
                If ($PSDrive){
                    write-verbose "$FunctionName`:  Connected to: $computer via SMB"
                    $Logpath = "$Computer`:\windows\system32\logfiles\firewall\pfirewall.log"
                    If (test-path $Logpath){
                        $Return = Get-content $logpath
                    }
                    Remove-PSDrive $PSDrive
                } else {Throw}
            } Catch{
                if ($PSDrive){Remove-PSDrive $PSDrive}
                write-verbose "$FunctionName`:  SMB Connection failed to $computer, attempting WSMAN connection"
                $ConnectionMethod='WSMAN'
            }
        }
        #if SMB fails, attemt to use a powershell remote session to retrieve the contents (this can be much slower for a large file)
        If ($ConnectionMethod -eq 'WSMAN'){
            write-verbose "$FunctionName`:  Attempting WSMAN connection to $computer"
            Try {
                If ($Credential){
                    $Session = New-PSSession -ComputerName $Computer -Credential $Credential
                } else {
                    $Session = New-PSSession -ComputerName $Computer
                }
                If ($Session) {Write-verbose "Connected to: $Computer via WSMAN"} else {Throw}
            } Catch {
                write-error "Unable to connect to $computer"
                return
            }
            $return = invoke-command -ScriptBlock {get-content c:\windows\system32\logfiles\firewall\pfirewall.log} -Session $Session
            write-verbose "$FunctionName`:  Removing session $Session"
            Remove-PSSession $Session
        }
        #if either of the above methods returned data, run through the parser to output an object
        if ($Return) {
            If ($Return.length -le 7){
                Write-Verbose "$FunctionName`:  Firewall log found, but empty.  No blocked traffic reported"
            } else {
                $output = $Return | ConvertFrom-String -TemplateContent $FirewallLogTemplate
                write-output $output
            }
        } else {
            write-error "No firewall log found.  Check firewall state" -ea continue
        }
    }
}
