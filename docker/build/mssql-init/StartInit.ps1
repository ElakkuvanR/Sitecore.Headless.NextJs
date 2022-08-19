[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$ResourcesDirectory,

    [Parameter(Mandatory)]
    [string]$SqlServer,

    [Parameter(Mandatory)]
    [string]$SqlAdminUser,

    [Parameter(Mandatory)]
    [string]$SqlAdminPassword,

    [Parameter(Mandatory)]
    [string]$SitecoreAdminPassword,

    [string]$SqlElasticPoolName,
    [object[]]$DatabaseUsers,

    [string]$DatabasesToDeploy,

    [int]$PostDeploymentWaitPeriod
)
$prefix = [System.Environment]::GetEnvironmentVariable("SQL_DATABASE_PREFIX")
$databaseConst = '[
    {
        "name": "'+$prefix+'.Sitecore.Core",
        "scripts": [
            "CreateUser.Core.sql",
            "SetSitecoreAdminPassword.sql"
        ],
        "dacpacs": [
            "Sitecore.Core.dacpac"
        ]
    },
    {
        "name": "'+$prefix+'.Sitecore.Master",
        "scripts": [
            "CreateUser.Master.sql"
        ],
        "dacpacs": [
            "Sitecore.Master.dacpac"
        ]
    },
    {
        "name": "'+$prefix+'.Sitecore.Web",
        "scripts": [
            "CreateUser.Web.sql"
        ],
        "dacpacs": [
            "Sitecore.Web.dacpac"
        ]
    },
    {
        "name": "'+$prefix+'.Sitecore.Experienceforms",
        "scripts": [
            "CreateUser.ExperienceForms.sql"
        ],
        "dacpacs": [
            "Sitecore.Experienceforms.dacpac"
        ]
    }
]';

$deployDatabases = $true
# Push the above content into the databases.json resource file
Set-Content -Path $ResourcesDirectory\databases.json -Value $databaseConst

if (-not $DatabasesToDeploy) {
    $serverDatabasesQuery = "SET NOCOUNT ON; SELECT name FROM sys.databases"
    $serverDatabases = Invoke-Expression "sqlcmd -S $SqlServer -U $SqlAdminUser -P $SqlAdminPassword -Q '$serverDatabasesQuery' -h -1 -W"

    $existingDatabases = Get-ChildItem $ResourcesDirectory -Filter *.dacpac -Recurse -Depth 1 | `
                            Where-Object { $serverDatabases.Contains($prefix+"."+$_.BaseName)}
    if ($existingDatabases.Count -gt 0) {
        Write-Information -MessageData "Sitecore databases are detected. Skipping deployment." -InformationAction Continue
        $deployDatabases = $false
    }
}

if ($deployDatabases) {
    Write-Information -MessageData "ResourcesDirectory is $ResourcesDirectory" -InformationAction Continue
    .\DeployDatabases.ps1 -ResourcesDirectory $ResourcesDirectory -SqlServer:$SqlServer -SqlAdminUser:$SqlAdminUser -SqlAdminPassword:$SqlAdminPassword -EnableContainedDatabaseAuth -SkipStartingServer -SqlElasticPoolName $SqlElasticPoolName -DatabasesToDeploy $DatabasesToDeploy -DatabasePrefixName $prefix

    if(-not $DatabasesToDeploy) {
        if(Test-Path -Path (Join-Path $ResourcesDirectory "smm_azure.sql")) {
            .\InstallShards.ps1 -ResourcesDirectory $ResourcesDirectory -SqlElasticPoolName $SqlElasticPoolName -SqlServer $SqlServer -SqlAdminUser $SqlAdminUser -SqlAdminPassword $SqlAdminPassword
        }
    
        .\SetDatabaseUsers.ps1 -ResourcesDirectory $ResourcesDirectory -SqlServer:$SqlServer -SqlAdminUser:$SqlAdminUser -SqlAdminPassword:$SqlAdminPassword `
            -DatabaseUsers $DatabaseUsers   
        .\SetSitecoreAdminPassword.ps1 -ResourcesDirectory $ResourcesDirectory -SitecoreAdminPassword $SitecoreAdminPassword -SqlServer $SqlServer -SqlAdminUser $SqlAdminUser -SqlAdminPassword $SqlAdminPassword -DatabasePrefixName $prefix
    }
}

[System.Environment]::SetEnvironmentVariable("DatabasesDeploymentStatus", "Complete", "Machine")

Start-Sleep -Seconds $PostDeploymentWaitPeriod