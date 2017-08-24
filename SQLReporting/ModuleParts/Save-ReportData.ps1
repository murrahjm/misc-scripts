function Save-ReportData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [object[]]$InputObject,

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
            $sql = "INSERT INTO $table ("
            $values = ""
            $needs_comma = $false

            foreach ($property in $properties) {
                if ($needs_comma) {
                    $sql += ","
                    $values += ","
                } else {
                    $needs_comma = $true
                }

                $sql += "[$property]"
                if ($object.($property) -is [int]) {
                    $values += $object.($property)
                } else {
                    $values += "'$($object.($property) -replace "'","''")'"
                }
            }

            $sql += ") VALUES($values)"
            Write-Verbose $sql
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
