# PowerShell script to compare user lists based on the first column (index 0)

# Parameters for the file paths - adjust these to your actual file locations
param (
    [string]$baseFilePath = "C:\Path\To\BaseUserList.csv",
    [string]$newImportFilePath = "C:\Path\To\NewImport.csv",
    [string]$outputFilePath = "C:\Path\To\Results.csv"
)

try {
    Write-Host "Importing base user list from $baseFilePath..."
    $baseData = Import-Csv -Path $baseFilePath
    
    Write-Host "Importing new user list from $newImportFilePath..."
    $newData = Import-Csv -Path $newImportFilePath
}
catch {
    Write-Error "Error importing files: $_"
    exit 1
}

# Get the header names for the first column in each file
$baseHeader = $baseData[0].PSObject.Properties.Name[0]
$newHeader = $newData[0].PSObject.Properties.Name[0]

Write-Host "Base file first column: $baseHeader"
Write-Host "New file first column: $newHeader"
Write-Host "Base users count: $($baseData.Count)"
Write-Host "New import users count: $($newData.Count)"

# Create dictionaries for faster lookups
$baseUserDict = @{}
$newUserDict = @{}

# Extract the username from the first column, regardless of its name
$baseData | ForEach-Object { $baseUserDict[$_.$baseHeader] = $_ }
$newData | ForEach-Object { $newUserDict[$_.$newHeader] = $_ }

# Create results array
$results = @()

# Process base users - find OK and Missing users
foreach ($baseUser in $baseData) {
    $userName = $baseUser.$baseHeader
    $status = if ($newUserDict.ContainsKey($userName)) { "OK" } else { "MISSING - CHECK" }
    
    # Create result object with all properties from base user plus status
    $resultObj = $baseUser.PSObject.Copy()
    $resultObj | Add-Member -MemberType NoteProperty -Name "Status" -Value $status
    $resultObj | Add-Member -MemberType NoteProperty -Name "Source" -Value "Base List"
    
    $results += $resultObj
}

# Process new users - find New users not in base
foreach ($newUser in $newData) {
    $userName = $newUser.$newHeader
    if (-not $baseUserDict.ContainsKey($userName)) {
        # New user not in base list
        $resultObj = $newUser.PSObject.Copy()
        $resultObj | Add-Member -MemberType NoteProperty -Name "Status" -Value "NEW"
        $resultObj | Add-Member -MemberType NoteProperty -Name "Source" -Value "New Import"
        
        $results += $resultObj
    }
}

# Export results to CSV
$results | Export-Csv -Path $outputFilePath -NoTypeInformation

# Summary counts
$okCount = ($results | Where-Object { $_.Status -eq "OK" }).Count
$missingCount = ($results | Where-Object { $_.Status -eq "MISSING - CHECK" }).Count
$newCount = ($results | Where-Object { $_.Status -eq "NEW" }).Count

Write-Host "--------------------------------"
Write-Host "Results Summary:"
Write-Host "OK users: $okCount"
Write-Host "Missing users: $missingCount"
Write-Host "New users: $newCount"
Write-Host "--------------------------------"
Write-Host "Results exported to: $outputFilePath"
