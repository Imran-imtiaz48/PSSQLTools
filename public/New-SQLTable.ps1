function New-SQLTable {
    <#
        .SYNOPSIS
        Creates a new SQL Server table.

        .DESCRIPTION
        This function connects to a SQL Server database and creates a table
        with the specified columns, schema, and database.

        .PARAMETER Table
        The name of the table to create.

        .PARAMETER Schema
        The schema to create the table in. Default is "dbo".

        .PARAMETER Database
        The target database.

        .PARAMETER Server
        The SQL Server instance name (only required if no connection is passed).

        .PARAMETER Connection
        An existing SQL connection object.

        .PARAMETER Columns
        Hashtable of column definitions, e.g. @{ Id = "INT PRIMARY KEY"; Name = "NVARCHAR(100)" }

        .EXAMPLE
        New-SQLTable -Database "TestDB" -Server "localhost" -Table "Employees" -Columns @{ Id = "INT PRIMARY KEY"; Name = "NVARCHAR(50)" }
    #>
    [CmdletBinding(DefaultParameterSetName = 'CreateConn')]
    param(
        [Parameter(Mandatory, Position=0)]
        [String]$Table,

        [Parameter(Position=1)]
        [String]$Schema = "dbo",

        [Parameter(Mandatory, Position=2)]
        [String]$Database,

        [Parameter(ParameterSetName='CreateConn', Mandatory, Position=3)]
        [String]$Server,

        [Parameter(ParameterSetName='PassedConn', Mandatory, Position=3)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory, Position=4)]
        [Hashtable]$Columns
    )

    ############# INITIALIZE CONNECTION ##################################
    if (-not $PSBoundParameters.ContainsKey('Connection')) {
        $Connection = New-Object System.Data.SqlClient.SqlConnection
        $Connection.ConnectionString = "Server=$Server; Database=$Database; Integrated Security=True"

        try {
            $Connection.Open()
        }
        catch {
            Write-Error "Failed to connect to SQL Server instance [$Server], database [$Database]. Error: $_"
            return
        }
    }
    elseif ($Connection.State -ne "Open") {
        $Connection.Open()
    }
    ######################################################################

    try {
        # Format columns
        $columnsFormatted = $Columns.Keys | ForEach-Object {
            "[" + $_ + "] " + $Columns[$_]
        } -join ", "

        $queryString = "CREATE TABLE [$Schema].[$Table] ($columnsFormatted);"

        Write-Verbose "Executing query: $queryString"

        $command = $Connection.CreateCommand()
        $command.CommandText = $queryString
        $command.ExecuteNonQuery()

        Write-Host "Table [$Schema].[$Table] created successfully in database [$Database]."
    }
    catch {
        Write-Error "Failed to create table [$Schema].[$Table]. Error: $_"
    }
    finally {
        if ($Connection.State -eq "Open" -and -not $PSBoundParameters.ContainsKey('Connection')) {
            $Connection.Close()
        }
    }
}
