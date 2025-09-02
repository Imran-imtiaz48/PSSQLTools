function Read-FromSQLTable {
    <#
        .SYNOPSIS
        Reads rows from a SQL Server table.

        .DESCRIPTION
        This function queries a SQL Server table and supports
        selecting all columns or a subset with modifiers like TOP or DISTINCT.
        You can pass an existing connection or let the function create its own.

        .PARAMETER SelectKeys
        Array of column names to select.

        .PARAMETER SelectAll
        Switch to select all columns ("SELECT *").

        .PARAMETER SelectModifier
        Optional modifier ("TOP" or "DISTINCT") applied to the query.

        .PARAMETER NumRows
        Number of rows to return if SelectModifier is TOP.

        .PARAMETER Order
        Sort order (ASCENDING or DESCENDING).

        .PARAMETER OrderBy
        Column to order the results by.

        .PARAMETER Table
        The SQL table name.

        .PARAMETER Schema
        The schema the table belongs to.

        .PARAMETER Database
        The target database.

        .PARAMETER Server
        The SQL Server instance (required if no connection is passed).

        .PARAMETER Connection
        A [System.Data.SqlClient.SqlConnection] object (optional).
        If passed, the function respects its state and does not close it.
    #>
    [CmdletBinding(DefaultParameterSetName = 'CreateConnAll')]
    param(
        [Parameter(Mandatory, ParameterSetName='CreateConnSome', Position=0)]
        [Parameter(Mandatory, ParameterSetName='PassedConnSome', Position=0)]
        [string[]]$SelectKeys,

        [Parameter(Mandatory, ParameterSetName='CreateConnAll', Position=0)]
        [Parameter(Mandatory, ParameterSetName='PassedConnAll', Position=0)]
        [switch]$SelectAll,

        [Parameter(ParameterSetName='CreateConnSome')]
        [Parameter(ParameterSetName='PassedConnSome')]
        [ValidateSet("TOP", "DISTINCT")]
        [string]$SelectModifier = "TOP",

        [Parameter(ParameterSetName='CreateConnSome')]
        [Parameter(ParameterSetName='PassedConnSome')]
        [int]$NumRows = 1,

        [Parameter(ParameterSetName='*Order')]
        [ValidateSet("ASCENDING", "DESCENDING")]
        [string]$Order = "DESCENDING",

        [Parameter(ParameterSetName='*Order')]
        [string]$OrderBy = "",

        [Parameter(ParameterSetName='*')]
        [string]$Table,

        [Parameter(ParameterSetName='*')]
        [string]$Schema = "dbo",

        [Parameter(Mandatory, ParameterSetName='*', Position=1)]
        [string]$Database,

        [Parameter(Mandatory, ParameterSetName='CreateConn*', Position=2)]
        [string]$Server,

        [Parameter(Mandatory, ParameterSetName='PassedConn*', Position=2)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    begin {
        $createdConnection = $false

        if (-not $Connection) {
            $Connection = New-Object System.Data.SqlClient.SqlConnection
            $Connection.ConnectionString = "Server=$Server; Database=$Database; Integrated Security=True"
            try {
                $Connection.Open()
                $createdConnection = $true
            }
            catch {
                Write-Error "Failed to connect to [$Server]\$Database. Error: $_"
                return
            }
        }
        elseif ($Connection.State -ne "Open") {
            $Connection.Open()
        }

        $query = $Connection.CreateCommand()
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter
    }

    process {
        # Build column list
        $keysFormatted = if ($SelectAll) {
            "*"
        }
        else {
            $SelectKeys | ForEach-Object { "[" + $_ + "]" } -join ", "
        }

        # Start query
        if ($SelectAll) {
            $queryText = "SELECT $keysFormatted FROM [$Schema].[$Table]"
        }
        else {
            $queryText = "SELECT $SelectModifier"
            if ($SelectModifier -eq "TOP") {
                $queryText += " ($NumRows)"
            }
            $queryText += " $keysFormatted FROM [$Schema].[$Table]"
        }

        # Add ORDER BY if specified
        if ($OrderBy) {
            $queryText += " ORDER BY [$OrderBy] "
            $queryText += if ($Order -eq "ASCENDING") { "ASC" } else { "DESC" }
        }

        Write-Verbose "Executing query: $queryText"

        # Run query
        $ds = New-Object System.Data.DataSet
        $query.CommandText = $queryText
        $adapter.SelectCommand = $query
        try {
            $adapter.Fill($ds) | Out-Null
        }
        catch {
            Write-Error "Query execution failed. Error: $_"
            return
        }

        $ds.Tables
    }

    end {
        if ($createdConnection -and $Connection.State -eq "Open") {
            $Connection.Close()
        }
    }
}
