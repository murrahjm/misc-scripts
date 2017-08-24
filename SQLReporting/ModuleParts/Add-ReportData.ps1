Function Add-ReportData {
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [object[]]$InputObject,

        [Parameter(Mandatory=$True)]
        [String[]]$KeyValues,

        [Parameter(Mandatory=$True,ParameterSetName='local')]
        [string]$LocalExpressDatabaseName,

        [Parameter(Mandatory=$True,ParameterSetName='remote')]
        [string]$ConnectionString

    )
    BEGIN{
        $FunctionName = $pscmdlet.MyInvocation.InvocationName.ToUpper()
    }
    PROCESS{
        $TypeName = $InputObject | Get-Member | select-object -first 1 | select -ExpandProperty TypeName
        If ($pscmdlet.ParameterSetName -eq 'local'){
            $CurrentData = Get-ReportData -TypeName $TypeName -LocalExpressDatabaseName $LocalExpressDatabaseName -ea SilentlyContinue
        } else {
            $CurrentData = Get-ReportData -TypeName $TypeName -ConnectionString $ConnectionString -ea SilentlyContinue
        }
        foreach ($item in $InputObject){
            write-verbose "$FunctionName`:  Processing item $item"
            $FilteredData = $CurrentData
            foreach ($key in $keyvalues){
                Write-Verbose "$FunctionName`:  Looking for values that match property name $key with value $($item.$key)"
                $FilteredData = $FilteredData | ?{$_.$key -eq $item.$key}
                write-verbose "$FunctionName`:  filtered item count:  $(@($FilteredData).count)"
            }
            If ($FilteredData){
                Write-verbose "$FunctionName`:  Entry exists for provided location, updating records"
                If ($pscmdlet.ParameterSetName -eq 'local'){
                    $item | Update-ReportData -keys $keyvalues -LocalExpressDatabaseName $LocalExpressDatabaseName
                } else {
                    $item | Update-ReportData -keys $keyvalues -ConnectionString $ConnectionString
                }
            } else {
                Write-verbose "$FunctionName`:  Location not found in database, adding new record"
                If ($pscmdlet.ParameterSetName -eq 'local'){
                    $item | Save-ReportData -LocalExpressDatabaseName $LocalExpressDatabaseName
                } else {
                    $item | Save-ReportData -ConnectionString $ConnectionString
                }
            }
        }
    }
    END{}
}
