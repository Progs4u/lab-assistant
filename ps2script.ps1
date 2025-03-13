# PowerShell script to extract new user details from reference CSV and export to Excel

# Parameters for the file paths - adjust these to your actual file locations
param (
    [string]$resultsFilePath = "C:\Path\To\results.csv",
    [string]$referenceFilePath = "C:\Path\To\reference.csv",
    [string]$outputExcelPath = "C:\Path\To\NewUsers.xlsx"
)

# Import required module for Excel export
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "Installing ImportExcel module..."
    Install-Module -Name ImportExcel -Force -Scope CurrentUser
}
Import-Module ImportExcel

try {
    Write-Host "Importing results file from $resultsFilePath..."
    $resultsData = Import-Csv -Path $resultsFilePath
    
    Write-Host "Importing reference data from $referenceFilePath..."
    $referenceData = Import-Csv -Path $referenceFilePath
}
catch {
    Write-Error "Error importing files: $_"
    exit 1
}

# Filter only NEW users from results
$newUsers = $resultsData | Where-Object { $_.Status -eq "NEW" }
Write-Host "Found $($newUsers.Count) new users to process"

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

# Get the username column from results
$usernameColumn = $newUsers[0].PSObject.Properties.Name[0]
Write-Host "Using username column: $usernameColumn"

# Get all reference columns for output
$referenceColumns = $referenceData[0].PSObject.Properties.Name
Write-Host "Reference data has $($referenceColumns.Count) columns"

# Create dictionary for faster lookup
$referenceDict = @{}
$userIdColumn = $referenceData[0].PSObject.Properties.Name[0]
Write-Host "Using reference ID column: $userIdColumn"

foreach ($refUser in $referenceData) {
    $userId = $refUser.$userIdColumn
    if ($null -ne $userId -and $userId -ne "") {
        $cleanedId = Clean-Value -value $userId
        if ($cleanedId -ne "") {
            $referenceDict[$cleanedId] = $refUser
        }
    }
}

# Create output data
$outputData = @()

# Match new users with reference data
foreach ($newUser in $newUsers) {
    $userId = $newUser.$usernameColumn
    $cleanedId = Clean-Value -value $userId
    
    if ($referenceDict.ContainsKey($cleanedId)) {
        $refUser = $referenceDict[$cleanedId]
        
        # Create object with all reference data
        $outputObj = [PSCustomObject]@{}
        
        # Add all reference properties
        foreach ($prop in $referenceColumns) {
            $outputObj | Add-Member -MemberType NoteProperty -Name $prop -Value $refUser.$prop
        }
        
        # Add status from results
        $outputObj | Add-Member -MemberType NoteProperty -Name "ImportStatus" -Value "NEW"
        $outputObj | Add-Member -MemberType NoteProperty -Name "CleanedValue" -Value $cleanedId
        
        $outputData += $outputObj
    }
    else {
        Write-Warning "No reference data found for user: $userId"
        
        # Add minimal information
        $outputObj = [PSCustomObject]@{
            $userIdColumn = $userId
            ImportStatus = "NEW - NO REFERENCE DATA"
            CleanedValue = $cleanedId
        }
        
        $outputData += $outputObj
    }
}

# Export to Excel
try {
    if ($outputData.Count -gt 0) {
        $outputData | Export-Excel -Path $outputExcelPath -WorksheetName "New Users" -AutoSize -TableName "NewUsers"
        Write-Host "Successfully exported $($outputData.Count) new users to $outputExcelPath"
    }
    else {
        Write-Warning "No matching data found to export."
    }
}
catch {
    Write-Error "Error exporting to Excel: $_"
    
    # Fallback to CSV if Excel export fails
    $csvPath = $outputExcelPath -replace "\.xlsx$", ".csv"
    $outputData | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Exported data to CSV instead: $csvPath"
}

Write-Host "--------------------------------"
Write-Host "Process complete!"
Write-Host "Total new users: $($newUsers.Count)"
Write-Host "Users with reference data: $($outputData.Count)"
Write-Host "--------------------------------"
