Function Get-AccountAttributeAge {
    <#
    .Synopsis
        Parses provided ad account and returns a timespan object for the specified parameters
    .DESCRIPTION
        Takes an ad object as input.  Based on the provided parameters and the swithes used, the output will be a timespan object representing the time between the current date and the timestamp of the attribute.
    .EXAMPLE
        get-aduser svc-app -properties * | Get-AccountAttributeAge -Logon
        This example returns the amount of time since the account last logged in to the domain
    .EXAMPLE    
        get-aduser svc-app -properties * | Get-AccountAttributeAge -Modify
        This example returns the amount of time since the account was modified in any way
        
    #>
        [CmdletBinding(DefaultParameterSetName = "byInputObject")]
        Param(
            [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName="Logon")]
            [ValidateNotNullOrEmpty()]
            $LastLogonTimestamp,
            [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName="Password")]
            [ValidateNotNullOrEmpty()]
            $PasswordLastSet,
            [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True,ParameterSetName="Modify")]
            [ValidateNotNullOrEmpty()]
            $whenChanged,
    
            [Parameter(Mandatory=$True,
                       Position=1,
                       ParameterSetName="byInputObject")]
            [System.Object]$InputObject,
    
            [Parameter(ParameterSetName="Logon")]
            [Switch]$Logon,
    
            [Parameter(ParameterSetName="Password")]
            [Switch]$Password,
    
            [Parameter(ParameterSetName="Modify")]
            [Switch]$Modify
        )
        BEGIN{
            $Today = get-date
            $BaseDate = [datetime]"January 1, 1601"
        }
        PROCESS{
            If ($InputObject){
                $inputObject | Get-AccountAttributeAge
            }
            else {
                If ($logon){
                    $LastLogondate = $BaseDate.AddTicks($lastlogontimestamp)
                    $age = $today - $LastLogonDate
                } elseif ($password) {
                    $age = $today - [datetime]$PasswordLastSet
                } elseif ($Modify) {
                    $age = $today - [datetime]$whenChanged
                }
                $age
            }
        }
        END{}
    }
    