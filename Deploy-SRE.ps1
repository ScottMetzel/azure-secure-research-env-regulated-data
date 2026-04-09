[System.String]$ARMTemplateFilePath = '.\bicep\main.bicep'
[System.String]$AzSubscriptionID = '<Hub-Sub-Az-Subscription-ID>'
[System.String]$Location = 'westus2'
[System.String]$ValidationLevel = 'Provider'

[System.String]$AdminUsername = '<Remote-Desktop-And-Researcher-VM-Local-Admin-Username>'
[System.String]$AdminPassword = '<Remote-Desktop-And-Researcher-VM-Local-Admin-Password>'
[System.Security.SecureString]$AdminPasswordSecure = ConvertTo-SecureString -String $AdminPassword -AsPlainText -Force

[System.Collections.Hashtable]$ARMTemplateParameterObject = @{
    'location'                     = $Location;
    'environmentName'              = 'Demo';
    'workloadName'                 = 'SRE';
    'adminUsername'                = $AdminUsername;
    'adminPassword'                = $AdminPasswordSecure;
    'BastionOrAVD'                 = 'Bastion';
    'researcherSubscriptionID'     = '<Researcher-Sub-Az-Subscription-ID>';
    'hubSubscriptionID'            = $AzSubscriptionID;
    'virtualDesktopSubscriptionID' = '<RemoteDesktop-Sub-Az-Subscription-ID>';
    'researcherVMSize'             = 'Standard_D4ds_v5';
    'researcherVMCount'            = 1;
    'dataApproverEmail'            = 'dataapprover@example.com';
}

$GetARMTemplateFile = Get-Item -Path $ARMTemplateFilePath
$GetARMTemplateFileBaseName = $GetARMTemplateFile.BaseName
$GetARMTemplateFilePath = $GetARMTemplateFile.ResolvedTarget
[System.String]$DateTime = Get-Date -Format FileDateTime
[System.String]$DeploymentName = [System.String]::Concat($GetARMTemplateFileBaseName, '_', $DateTime)

Get-AzSubscription -SubscriptionId $AzSubscriptionID | Set-AzContext

New-AzDeployment -Name $DeploymentName -Location $Location -TemplateFile $GetARMTemplateFilePath -TemplateParameterObject $ARMTemplateParameterObject -ValidationLevel $ValidationLevel -Verbose