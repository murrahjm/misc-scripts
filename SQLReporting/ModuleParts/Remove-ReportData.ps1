function Remove-ReportData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [object[]]$InputObject,

        [Parameter(Mandatory=$True)]
        [String[]]$Keys,

        [Parameter(Mandatory=$True,ParameterSetName='local')]
        [string]$LocalExpressDatabaseName,

        [Parameter(Mandatory=$True,ParameterSetName='remote')]
        [string]$ConnectionString
    )
    BEGIN {
        if ($PSBoundParameters.ContainsKey('LocalExpressDatabaseName')) {
            $ConnectionString = "Server=$(Get-Content Env:\COMPUTERNAME)\SQLEXPRESS;Database=$LocalExpressDatabaseName;Trusted_Connection=$True;"
        }
        Write-Verbose "Connection string is $ConnectionString"

        $conn = New-Object -TypeName System.Data.SqlClient.SqlConnection
        $conn.ConnectionString = $ConnectionString
        try {
            $conn.Open()
        } catch {
            throw "Failed to connect to $ConnectionString"
        }

        $SetUp = $false
    }
    PROCESS {
        foreach ($object in $InputObject) {
            if (-not $SetUp) {
                $table = Test-Database -ConnectionString $ConnectionString -Object $object
                $SetUp = $True
            }

            $properties = $object | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
            $sql = "DELETE FROM $table WHERE "
            $needs_comma = $false
            Foreach ($key in $keys){
                if ($needs_comma) {
                    $sql += " AND "
                } else {
                    $needs_comma = $true
                }

                if ($object.($key) -is [int]) {
                    $value = $object.($key)
                } else {
                    $value = "'$($object.($key) -replace "'","''")'"
                }
                $sql += "[$key]=$value"

            }
            Write-verbose $sql
            Write-Debug "Done building SQL for this object"

            $cmd = New-Object -TypeName System.Data.SqlClient.SqlCommand
            $cmd.Connection = $conn
            $cmd.CommandText = $sql
            $cmd.ExecuteNonQuery() | out-null
        }
    }
    END {
        $conn.close()
    }
}
