param(
    [Parameter(Mandatory)]
    [string]$SitecoreSolrConnectionString,

    [Parameter(Mandatory)]
    [string]$SolrSitecoreConfigsetSuffixName,

    [Parameter(Mandatory)]
    [string]$SolrCorePrefix,

    [Parameter(Mandatory)]
    [string]$SolrReplicationFactor,

    [Parameter(Mandatory)]
    [int]$SolrNumberOfShards,
    
    [Parameter(Mandatory)]
    [int]$SolrMaxShardsPerNodes,

    [string]$SolrXdbSchemaFile,
    
    [string]$SolrCollectionsToDeploy
)

function GetCoreNames {
    param (
        [ValidateSet("sitecore", "xdb")]
        [string]$CoreType,
        
        [string]$SolrCollectionsToDeploy
    )

    $resultCoreNames = @()
    $SolrCollectionsToDeploy.Split(',') | ForEach-Object {
        $solrCollectionToDeploy = $_
        Get-ChildItem C:\data -Filter "cores*$solrCollectionToDeploy.json" | ForEach-Object {
            $coreNames = (Get-Content $_.FullName | Out-String | ConvertFrom-Json).$CoreType
            if ($coreNames) {
                $resultCoreNames += $coreNames
            }
        }
    }

    return $resultCoreNames
}

function CreateCores {
    param (
        [string[]]$SolrCoreNames,
        [string]$SolrConfigDir,
        [string]$SolrBaseConfigsetName,
        $SolrCollectionAliases,
        [switch]$SolrXdbCore
    )

    .\New-SolrConfig.ps1 -SolrEndpoint $SolrEndpoint -SolrConfigName $SolrBaseConfigsetName -SolrConfigDir $SolrConfigDir

    foreach ($solrCoreName in $SolrCoreNames) {
        Write-Host "core name is created $solrCoreName"

        $solrConfigsetName = ('{0}{1}{2}' -f $SolrCorePrefix, $solrCoreName, $SolrSitecoreConfigsetSuffixName)
    
        .\Copy-SolrConfig.ps1 -SolrEndpoint $SolrEndpoint -SolrConfigName $solrConfigsetName -SolrBaseConfigName $SolrBaseConfigsetName
        
        .\New-SolrCore.ps1 -SolrCoreNames $solrCoreName -SolrEndpoint $SolrEndpoint -SolrCorePrefix $SolrCorePrefix -SolrConfigsetName $solrConfigsetName -SolrReplicationFactor $SolrReplicationFactor -SolrNumberOfShards $SolrNumberOfShards -SolrMaxShardNumberPerNode $SolrMaxShardsPerNodes -SolrCollectionAliases $SolrCollectionAliases

        if ($SolrXdbCore) {
            $solrCollectionName = ('{0}{1}' -f $SolrCorePrefix, $solrCoreName)
            .\Update-Schema.ps1 -SolrCollectionName $solrCollectionName -SolrEndpoint $SolrEndpoint -SchemaPath $SolrXdbSchemaFile
        }
    }
}

. .\Get-SolrCredential.ps1

$solrContext = .\Parse-ConnectionString.ps1 -SitecoreSolrConnectionString $SitecoreSolrConnectionString

$SolrEndpoint = $solrContext.SolrEndpoint
$env:SOLR_USERNAME = $solrContext.SolrUsername
$env:SOLR_PASSWORD = $solrContext.SolrPassword

$solrSitecoreCoreNames = GetCoreNames -CoreType "sitecore" -SolrCollectionsToDeploy $SolrCollectionsToDeploy
$solrXdbCoreNames = GetCoreNames -CoreType "xdb" -SolrCollectionsToDeploy $SolrCollectionsToDeploy
Write-Host "solrSitecoreCoreNames $solrSitecoreCoreNames"
Write-Host "SolrEndpoint $SolrEndpoint"
$solrCollections = (Invoke-RestMethod -Uri "$SolrEndpoint/admin/collections?action=LIST&omitHeader=true" -Method Get -Credential (Get-SolrCredential)).collections
Write-Host "solrCollections already $solrCollections"
foreach ($solrCoreName in ($solrSitecoreCoreNames + $solrXdbCoreNames)) {
    if ($solrCollections -contains ('{0}{1}' -f $SolrCorePrefix, $solrCoreName)) {
        Write-Information -MessageData "Sitecore collections are already exist. Use collection name prefix different from '$SolrCorePrefix'." -InformationAction:Continue
        return
    }    
}

$solrConfigDir = "C:\temp\sitecore_content_config"
$solrBaseConfigDir = "C:\temp\default"
.\Download-SolrConfig.ps1 -SolrEndpoint $SolrEndpoint -OutPath $solrBaseConfigDir
.\Patch-SolrConfig.ps1 -SolrConfigPath $solrBaseConfigDir -XsltPath "C:\data\xslt" -OutputPath $solrConfigDir

$collectionAliases = $null
if(Test-Path -Path "C:\data\aliases.json") {
    $collectionAliases = ((Get-Content C:\data\aliases.json | Out-String | ConvertFrom-Json).aliases)
}

CreateCores -SolrCoreNames $solrSitecoreCoreNames -SolrConfigDir $solrConfigDir -SolrBaseConfigsetName "$($SolrCorePrefix)_content_config"
Write-Host "solrCollections created $solrSitecoreCoreNames"

if($solrXdbCoreNames) 
{
    CreateCores -SolrCoreNames $solrXdbCoreNames -SolrConfigDir $solrBaseConfigDir -SolrBaseConfigsetName "$($SolrCorePrefix)_xdb_config" -SolrCollectionAliases $collectionAliases -SolrXdbCore
}