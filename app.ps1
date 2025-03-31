# ------------------------
# Parameters
# ------------------------

param(
    [Parameter(Position=0,mandatory=$true)]
    [string]$ProjectName,
    [Parameter(Position=1,mandatory=$true)]
    [string]$Location
)

# ------------------------
# Build and push container image
# ------------------------

Write-Host "Building and pushing job image..."

$sourcePath = "src/DemoApi"

$containerImageName = "demo-api"
$containerImageTag = "latest"
$awsAccessKeyId = [Environment]::GetEnvironmentVariable('AWS_ACCESS_KEY_ID')
$awsSecretAccessKey = [Environment]::GetEnvironmentVariable('AWS_SECRET_ACCESS_KEY')
$acrName = "$($ProjectName.ToLower())acr".Replace("-", "")

$fullImageName = "$acrName.azurecr.io/$($containerImageName):$($containerImageTag)"

docker build -t $fullImageName $sourcePath --platform linux/amd64

az acr login --name $acrName

docker push $fullImageName

# ------------------------
# Deploy Jon Bicep Template
# ------------------------

Write-Host "Deploying container to Azure..."

$resourceGroupName = $ProjectName + "-rg"

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile .\app.bicep -TemplateParameterObject @{ 
    projectName = $ProjectName 
    awsAccessKeyId = $awsAccessKeyId 
    awsSecretAccessKey = $awsSecretAccessKey
    }