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

# Get column information
Write-Host "Examining file structure..."
$baseHeaders = $baseData[0].PSObject.Properties.Name
$newHeaders = $newData[0].PSObject.Properties.Name

# Print all column headers to help diagnose
Write-Host "`nBase file columns: $($baseHeaders -join ', ')"
Write-Host "New file columns: $($newHeaders -join ', ')"

# Let's look at the actual data
Write-Host "`nExamining first row of base file:"
$firstBaseRow = $baseData[0]
foreach ($prop in $baseHeaders) {
    Write-Host "  $prop = [$($firstBaseRow.$prop)]"
}

Write-Host "`nExamining first row of new file:"
$firstNewRow = $newData[0]
foreach ($prop in $newHeaders) {
    Write-Host "  $prop = [$($firstNewRow.$prop)]"
}

# Try to determine which columns contain usernames to compare
Write-Host "`nAttempting to identify username columns..."

# Ask user to select columns for comparison
Write-Host "`nPlease select columns to use for comparison:"
Write-Host "Base file columns:"
for ($i = 0; $i -lt $baseHeaders.Count; $i++) {
    Write-Host "  $i: $($baseHeaders[$i])"
}

$baseColumnIndex = Read-Host "Enter the number of the column from the base file to use"
$baseHeader = $baseHeaders[$baseColumnIndex]

Write-Host "`nNew file columns:"
for ($i = 0; $i -lt $newHeaders.Count; $i++) {
    Write-Host "  $i: $($newHeaders[$i])"
}

$newColumnIndex = Read-Host "Enter the number of the column from the new file to use"
$newHeader = $newHeaders[$newColumnIndex]

Write-Host "`nUsing base column: $baseHeader"
Write-Host "Using new column: $newHeader"

# Create dictionaries for faster lookups
$baseUserDict = @{}
$newUserDict = @{}

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

# Populate dictionaries with cleaned values
foreach ($baseUser in $baseData) {
    if ($null -ne $baseUser -and ![string]::IsNullOrWhiteSpace($baseUser.$baseHeader)) {
        $cleanedValue = Clean-Value -value $baseUser.$baseHeader
        if (![string]::IsNullOrWhiteSpace($cleanedValue)) {
            $baseUserDict[$cleanedValue] = $baseUser
            Write-Host "Added base user: $cleanedValue"
        }
    }
}

foreach ($newUser in $newData) {
    if ($null -ne $newUser -and ![string]::IsNullOrWhiteSpace($newUser.$newHeader)) {
        $cleanedValue = Clean-Value -value $newUser.$newHeader
        if (![string]::IsNullOrWhiteSpace($cleanedValue)) {
            $newUserDict[$cleanedValue] = $newUser
            Write-Host "Added new user: $cleanedValue"
        }
    }
}

# Create results array
$results = @()

# Process base users - find OK and Missing users
foreach ($baseUser in $baseData) {
    if ($null -ne $baseUser -and ![string]::IsNullOrWhiteSpace($baseUser.$baseHeader)) {
        $cleanedValue = Clean-Value -value $baseUser.$baseHeader
        if (![string]::IsNullOrWhiteSpace($cleanedValue)) {
            $status = if ($newUserDict.ContainsKey($cleanedValue)) { "OK" } else { "MISSING - CHECK" }
            
            # Create result object with all properties from base user plus status
            $resultObj = $baseUser.PSObject.Copy()
            $resultObj | Add-Member -MemberType NoteProperty -Name "Status" -Value $status
            $resultObj | Add-Member -MemberType NoteProperty -Name "Source" -Value "Base List"
            $resultObj | Add-Member -MemberType NoteProperty -Name "CleanedValue" -Value $cleanedValue
            
            $results += $resultObj
        }
    }
}

# Process new users - find New users not in base
foreach ($newUser in $newData) {
    if ($null -ne $newUser -and ![string]::IsNullOrWhiteSpace($newUser.$newHeader)) {
        $cleanedValue = Clean-Value -value $newUser.$newHeader
        if (![string]::IsNullOrWhiteSpace($cleanedValue)) {
            if (-not $baseUserDict.ContainsKey($cleanedValue)) {
                # New user not in base list
                $resultObj = $newUser.PSObject.Copy()
                $resultObj | Add-Member -MemberType NoteProperty -Name "Status" -Value "NEW"
                $resultObj | Add-Member -MemberType NoteProperty -Name "Source" -Value "New Import"
                $resultObj | Add-Member -MemberType NoteProperty -Name "CleanedValue" -Value $cleanedValue
                
                $results += $resultObj
            }
        }
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
