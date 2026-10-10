<#
.SYNOPSIS
    Bulk user creation in Active Directory from a CSV input file.
.DESCRIPTION
    Reads new employee records from a CSV file, verifies input integrity, 
    creates Active Directory accounts in the designated OU, sets default 
    passwords, and flags accounts for password reset on first login.
.PARAMETER CsvPath
    Specifies the local path to the CSV file containing employee details.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$CsvPath
)

Import-Module ActiveDirectory

if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found at path: $CsvPath"
    exit 1
}

$Users = Import-Csv -Path $CsvPath

foreach ($User in $Users) {
    $SAM = $User.SamAccountName
    $TargetOU = $User.TargetOU
    $UPN = "$SAM@$($User.Domain)"
    $SecurePassword = ConvertTo-SecureString $User.DefaultPassword -AsPlainText -Force

    try {
        # Check if the user already exists
        if (Get-ADUser -Filter "SamAccountName -eq '$SAM'") {
            Write-Warning "User $SAM already exists in Active Directory. Skipping."
            continue
        }

        # Provision new AD account
        New-ADUser `
            -Name "$($User.FirstName) $($User.LastName)" `
            -GivenName $User.FirstName `
            -Surname $User.LastName `
            -SamAccountName $SAM `
            -UserPrincipalName $UPN `
            -Path $TargetOU `
            -AccountPassword $SecurePassword `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -Department $User.Department `
            -Title $User.Title

        Write-Host "Successfully provisioned account: $SAM in OU:$TargetOU" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to provision user $SAM. Error: $($_.Exception.Message)"
    }
}
