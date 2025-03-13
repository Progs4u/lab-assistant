# PowerShell script to compare user lists - simplified version

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

# Get all column names
$baseHeaders = @($baseData[0].PSObject.Properties.Name)
$newHeaders = @($newData[0].PSObject.Properties.Name)

Write-Host "Base file columns: $($baseHeaders -join ', ')"
Write-Host "New file columns: $($newHeaders -join ', ')"

# Manual selection - hardcode the column names for comparison
$baseHeader = $baseHeaders[0]  # First column of base file
$newHeader = $newHeaders[0]    # First column of new file

Write-Host "Using base column: $baseHeader"
Write-Host "Using new column: $newHeader"

# Function to clean and normalize values for comparison
function Clean-Value {
    param (
        [string]$value
    )
    
    if ($null -eq $value) { return "" }
    
    # Remove brackets, quotes, and whitespace
    $cleaned = $value -replace '[\[\]\"]', '' -replace '\s+', ''
    return $cleaned.Trim().ToLower()
}

# Create dictionaries for faster lookups
$baseUserDict = @{}
$newUserDict = @{}

# Create results array
$results = @()

# First, process the new users to build the dictionary
foreach ($newUser in $newData) {
    $rawValue = $newUser.$newHeader
    if ($null -ne $rawValue -and $rawValue -ne "") {
        $cleanedValue = Clean-Value -value $rawValue
        if ($cleanedValue -ne "") {
            $newUserDict[$cleanedValue] = $newUser
        }
    }
}

# Process base users and check against new users
foreach ($baseUser in $baseData) {
    $rawValue = $baseUser.$baseHeader
    if ($null -ne $rawValue -and $rawValue -ne "") {
        $cleanedValue = Clean-Value -value $rawValue
        if ($cleanedValue -ne "") {
            $status = if ($newUserDict.ContainsKey($cleanedValue)) { "OK" } else { "MISSING - CHECK" }
            
            # Create result object
            $resultObj = [PSCustomObject]@{
                Username = $rawValue
                Status = $status
                Source = "Base List"
                CleanedValue = $cleanedValue
            }
            
            $results += $resultObj
            
            # Remove from new user dict if found (to track only new users later)
            if ($status -eq "OK") {
                $newUserDict.Remove($cleanedValue)
            }
        }
    }
}

# Add remaining new users to results
foreach ($key in $newUserDict.Keys) {
    $newUser = $newUserDict[$key]
    $rawValue = $newUser.$newHeader
    
    $resultObj = [PSCustomObject]@{
        Username = $rawValue
        Status = "NEW"
        Source = "New Import"
        CleanedValue = $key
    }
    
    $results += $resultObj
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
