function Get-ReportData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$TypeName,

        [Parameter(Mandatory=$True,ParameterSetName='local')]
        [string]$LocalExpressDatabaseName,

        [Parameter(Mandatory=$True,ParameterSetName='remote')]
        [string]$ConnectionString
    )
    
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

    $table = "$($TypeName.split('.')[1].ToLower())"
    Write-Verbose "Table name is $Table"

    if ($TypeName.split('.')[0] -ne 'Report') {
        throw "Illegal type name on input object - aborting - please read the book!"
    }

    # Test to see if table exists
    $sql = "SELECT COUNT(*) AS num FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND LOWER(TABLE_NAME) = '$Table'"
    write-verbose $sql
    $cmd = New-Object -TypeName System.Data.SqlClient.SqlCommand
    $cmd.CommandText = $sql
    $cmd.Connection = $conn
    $result = $cmd.ExecuteReader()
    $result.read() | out-null
    $num_rows = $result.GetValue(0)
    $result.close() | Out-Null

    if ($num_rows -eq 0) {
        throw "Table for $TypeName not found in database"
    }

    # Need to get the schema for this table
    $sql = "select c.name, t.name from sys.columns c inner join sys.types t on c.system_type_id = t.system_type_id left outer join sys.index_columns ic on ic.object_id = c.object_id and ic.column_id = c.column_id left outer join sys.indexes i on ic.object_id = i.object_id and ic.index_id = i.index_id where t.name <> 'sysname' AND c.object_id = OBJECT_ID('$table')"
    Write-Verbose $sql

    $cmd.CommandText = $sql
    $result = $cmd.ExecuteReader()
    $properties = @{}
    while ($result.read()) {
        $properties.add($result.GetString(0),$result.getstring(1))
    }
    $result.close() | out-null

    Write-Debug "Constructed property bag"

    # construct query to get columns in known order
    $sql = "SELECT "
    $needs_comma = $false
    foreach ($property in $properties.keys) {
        if ($needs_comma) {
            $sql += ","
        } else {
            $needs_comma = $True
        }
        $sql += "[$property]"
    }
    $sql += " FROM $table"

    # query rows
    Write-Verbose $sql
    $cmd.commandtext = $sql
    $result = $cmd.executereader()
    while ($result.read()) {
        Write-Verbose "Reading row and constructing object"
        $obj = New-Object -TypeName PSObject
        $obj.PSObject.TypeNames.Insert(0,$TypeName)
        foreach ($property in $properties.keys) {
            Write-Verbose "  $property"
            Try {
                if ($properties[$property] -eq 'datetime2') { [datetime]$prop = $result.GetDateTime($result.GetOrdinal($property)) }
                if ($properties[$property] -eq 'bigint') { [uint64]$prop = $result.GetInt64($result.GetOrdinal($property)) }
                if ($properties[$property] -eq 'nvarchar') { [string]$prop = $result.GetString($result.GetOrdinal($property)) }
            } Catch {
                $prop = $null
            } Finally {
                $obj | Add-Member -MemberType NoteProperty -Name $property -Value $prop
            }
        }
        #Write-Debug "Object constructed"
        Write-Output $obj
    }

    $result.close() | out-null
    $conn.close() | out-null
 }
