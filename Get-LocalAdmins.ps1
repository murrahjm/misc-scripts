Function Get-LocalAdmins {
    <#
    .SYNOPSIS
        Retrieves members of the local Administrators group for a given computername
    .DESCRIPTION
        Connects to the given computername and uses the ADSI provider to retrieve members of the local Administrators group.
    .PARAMETER ComputerName
        Specifies the computer to connect to and retrieve data.  Accepts pipeline input and multiple values.
    .EXAMPLE
        Retreive a list of computers from a text file and retrieves local admin membership for each
        Get-Content names.txt | Get-LocalAdmins
    .EXAMPLE
        Get local Administrators group membership for a single computer
        Get-LocalAdmins -ComputerName 'server1'
    .EXAMPLE
        Get all computer objects in Servers OU and retrieve local admin members for each.
        Get-ADComputer -filter * -searchbase "ou=Servers,dc=domain,dc=com" | Get-LocalAdmins
    .EXAMPLE
        Get local admin membership for a list of computers and output to a CSV file.
        Get-content serverlist.txt | Get-LocalAdmins | export-csv c:\temp\members.csv -NoTypeInformation
    #>
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory=$True,
                       ValueFromPipeline=$True)]
            [ValidateNotNullorEmpty()]
            [string[]]$Computername
        )
        BEGIN{
            $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
            write-verbose "$FunctionName`:  Beginning Get-LocalAdmins"
        }
        PROCESS{
            Foreach ($computer in $Computername){
                if ($computer.Name){
                    write-verbose "$FunctionName`:  Parameter is object, retrieving Name value"
                    $computer = $computer.name
                }
                write-verbose "$FunctionName`:  Processing $computer"
                Try {
                    Test-Connection -Quiet -count 1 -computername $Computer -EA Stop
                    write-verbose "$FunctionName`:  Server $computer online, pulling admin list"
                    ([ADSI]"WinNT://$computer/Administrators").psbase.invoke('Members') | 
                    ForEach-Object{
                        $member=$_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null)
                        $output = New-Object PSObject -Property @{Server=$computer;Member=$member}
                        Write-Output $output
                    }
                } Catch {
                    write-verbose "$FunctionName`:  Error connecting to $computer"
                }
            }
        }
        END{
            write-verbose "$FunctionName`:  Get-LocalAdmins"
        }
    }
    