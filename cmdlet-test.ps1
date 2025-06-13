param(
    [Parameter(Mandatory=$false)][String]$ResourceGroupName,
    [Parameter(Mandatory=$false)][String]$CloudServiceName,
    [Parameter(Mandatory=$false)][String]$SubscriptionId,
    [Parameter(Mandatory=$false)][String]$StorageAccountName,
    [Parameter(Mandatory=$false)][String]$StorageAccountKey,
    [Parameter(Mandatory=$false)][String]$Container,
    [Parameter(Mandatory=$false)][String]$DeploymentEnvironment,
    [Parameter(Mandatory=$false)][String]$AzureApplicationId,
    [Parameter(Mandatory=$false)][String]$AzureTenantId,
    [Parameter(Mandatory=$false)][String]$AzurePassword
)

try
{
    Write-Output "Connecting to Azure. AzureApplicationId: $AzureApplicationId"

    # Log into Azure
    # Note: $AzurePassword will expire every two years:
    # Expires October 10, 2026

    #$azurePasswordSecureString = ConvertTo-SecureString $AzurePassword -AsPlainText -Force
    #$psCred = New-Object System.Management.Automation.PSCredential($AzureApplicationId, $azurePasswordSecureString)
    $defaultProfile = Connect-AzAccount -Credential $psCred -TenantId $AzureTenantId  -ServicePrincipal

    Write-Output "Connected to Azure, getting the cloud service definition. CloudServiceName: $CloudServiceName"

    # Get existing cloud service
    $cloudService = Get-AzCloudService -DefaultProfile $defaultProfile `
        -ResourceGroupName $ResourceGroupName `
        -CloudServiceName $CloudServiceName `
        -SubscriptionId $SubscriptionId

    Write-Output "Loaded cloud service definition"
    $cloudService | Select-Object

    # Create SAS URL to the package url blob: https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-user-delegation-sas-create-powershell
    # All environments declare the StorageAccountKey as an encrypted environment variable.
    # (See https://ci.appveyor.com/environments)
    $storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
    $expiryDate = (Get-Date).AddHours(1)
    Write-Output "Getting SAS tokens, (expire at $expiryDate)"
    
    Write-Output "Getting SAS token for $Env:APPVEYOR_BUILD_VERSION/CloudServicePackages/$DeploymentEnvironment/CloudService.cspkg"
    $cloudService.PackageUrl = New-AzStorageBlobSASToken -Context $storageContext `
        -Container $Container `
        -Blob "$Env:APPVEYOR_BUILD_VERSION/CloudServicePackages/$DeploymentEnvironment/CloudService.cspkg" `
        -Permission r `
        -ExpiryTime $expiryDate `
        -FullUri

    # ServiceDefinition.csdef comes from the build tree, but ServiceConfiguration.xx.cscfg comes from the build artifacts in case the build changes it in some way
    $deploymentXmlPath = "$Env:APPVEYOR_BUILD_FOLDER\CloudService\ServiceDefinition.csdef"
    $configurationXmlPath = "$Env:APPVEYOR_BUILD_FOLDER\$Env:APPVEYOR_BUILD_VERSION\CloudServicePackages\$DeploymentEnvironment\ServiceConfiguration.$DeploymentEnvironment.cscfg"
    Write-Output "Loaded SAS tokens, getting configuration XML from $configurationXmlPath"

    $configurationXml = [System.IO.File]::ReadAllText($configurationXmlPath)
    Write-Output "Loaded configuration XML, sleeping for 45 seconds"
    Start-Sleep -Seconds 45

    Write-Output "Updating service"

    # Setting ConfigurationUrl is problematic, because removing the Configuration field doesn't work
    $cloudService.Configuration = $configurationXml

    # Construct the roles from the csdef and cscfg files
    $vmSizes = @{}

    # Figure out VM counts from the cscfg
    [Xml]$csdefXml = Get-Content $deploymentXmlPath
    Foreach ($workerrole_tag in $csdefXml.ServiceDefinition.WorkerRole) 
    {
        $vmSizes[$workerrole_tag.name] = $workerrole_tag.vmsize
    }

    # And get vm names and sizes from the csdef
    [Xml]$cscfgXml = Get-Content $configurationXmlPath 
    $roles = @()
    Foreach ($role_tag in $cscfgXml.ServiceConfiguration.Role) 
    {
        $role = New-AzCloudServiceRoleProfilePropertiesObject -Name $role_tag.name -SkuName $vmSizes[$role_tag.name] -SkuTier 'Standard' -SkuCapacity $role_tag.Instances.count
        $roles += $role;
    }

    Write-Output "Deploying roles:"
    Write-Output $roles
    $cloudService.RoleProfile = @{role = $roles} 

    # Allow updating worker roles and counts
    # https://learn.microsoft.com/en-us/azure/cloud-services-extended-support/override-sku
    $cloudService.AllowModelOverride = true

    # Set tags
    $cloudService.Tag.Clear()
    $cloudService.Tag["DeploymentLabel"] = $Env:APPVEYOR_BUILD_VERSION
    $cloudService.Tag["PullRequestId"] = $Env:APPVEYOR_PULL_REQUEST_NUMBER
    $cloudService.Tag["CommitId"] = $Env:APPVEYOR_REPO_COMMIT
    $cloudService.Tag["Branch"] = $Env:APPVEYOR_REPO_BRANCH
    $cloudService.Tag["Date"] = (Get-Date)

    # https://learn.microsoft.com/en-us/powershell/module/az.cloudservice/update-azcloudservice?view=azps-8.3.0
    $updatedCloudService = $cloudService | Update-AzCloudService -DefaultProfile $defaultProfile 

    # Check that the service actually updated. The update can fail, but the script passes
    if ($cloudService.Configuration -eq $updatedCloudService.Configuration)
    {
        Write-Output "Updated service successfully"

        exit 0
    }
    else
    {
        Write-Output "Service update failed"

        exit 10
    }
} 
catch [System.Exception] 
{ 
    Write-Error "======"
    Write-Error $_.Exception.ToString()
    exit 1 
}
