function Test-Database {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [object]$object
    )

    # Connect
    $conn = New-Object -TypeName System.Data.SqlClient.SqlConnection
    $conn.ConnectionString = $ConnectionString
    $conn.Open() | Out-null

    $TypeName = $object | Get-Member | select-object -ExpandProperty TypeName
    $Properties = $object | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name

    $Table = $typename.split('.')[1]
    Write-Verbose "Table name is $Table"

    if ($TypeName.split('.')[0] -ne 'Report') {
        throw "Illegal type name on input object - aborting - please read the book!"
    }

    # Test to see if table exists
    $sql = "SELECT COUNT(*) AS num FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND LOWER(TABLE_NAME) = '$($Table.tolower())'"
    write-verbose $sql
    $cmd = New-Object -TypeName System.Data.SqlClient.SqlCommand
    $cmd.CommandText = $sql
    $cmd.Connection = $conn
    $result = $cmd.ExecuteReader()
    $result.read() | out-null
    $num_rows = $result.GetValue(0)
    Write-Debug "Tested for table"
    $result.close() | Out-Null

    $table = "[$table]"

    if ($num_rows -gt 0) {
        # Table exists
        $conn.close() | Out-Null
        return $table
    } else {
        # Table doesn't exist
        $sql = "CREATE TABLE dbo.$table ("
        $needs_comma = $false
        $indexes = @()

        foreach ($property in $Properties) {
            if ($needs_comma) {
                $sql += ','
            } else {
                $needs_comma = $True
            }

            if ($object.($property) -is [int] -or
                $object.($property) -is [int32] -or
                $object.($property) -is [uint32] -or
                $object.($property) -is [int64] -or
                $object.($property) -is [uint64]) {
                $sql += "[$property] BIGINT"
            } elseif ($object.($property) -is [datetime]) {
                $sql += "[$property] DATETIME2"
            } else {
                $sql += "[$property] NVARCHAR(MAX)"
            }

            if ($property -in @('name','computername','collected')) {
                $indexes += $property
            }

        }
        $sql += ")"
        Write-Debug "$sql"

        $cmd.CommandText = $sql
        $cmd.ExecuteNonQuery() | out-null

        foreach ($index in $indexes) {
            $sql = "CREATE NONCLUSTERED INDEX [idx_$index] ON $table([$index])"
            Write-Debug "$sql"
            $cmd.CommandText = $sql
            $cmd.ExecuteNonQuery() | out-null
        }

        $conn.close()
        return $table
    }

}
