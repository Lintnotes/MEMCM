<#
.SYNOPSIS
    Collects Geolocation Information and stores in registry.
.DESCRIPTION
    This script will attempt to connect to a Geolocation API and collect location information based on external IP and stamp in the registry for tracking.
.EXAMPLE
    Get-Geolocation.ps1
.NOTES
    FileName:   Get-Geolocation.ps1
    Author:     Brandon Linton
    Contact:    @Lintnotes
    Created:    2022-01-07
    Updated:
    Version History:
        1.0.0 - (2022-01-07) - Script Created

    Links: https://github.com/Azure/WindowsVMAgent/blob/main/release-notes/2.7.md

Disclaimer. The sample scripts are not supported under any Microsoft standard support program or service.
The sample scripts are provided AS IS without warranty of any kind.
Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.
#>

# Relaunch script as sysnative if architecture is amd64
If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch {
        Throw "Failed to start $PSCOMMANDPATH"
    }
    Exit
}

# Define Functions
Function Get-IPGeolocation {
    $GeoAPIRequest = Invoke-RestMethod -Method Get -Uri "https://ipapi.co/json"

    [PSCustomObject]@{
        IP        = $GeoAPIRequest.IP
        City      = $GeoAPIRequest.City
        State     = $GeoAPIRequest.Region_Code
        Postal    = $GeoAPIRequest.Postal
        Country   = $GeoAPIRequest.Country_Name
        Code      = $GeoAPIRequest.Country_Code
        Continent = $GeoAPIRequest.Continent_Code
        Latitude  = $GeoAPIRequest.Latitude
        Longitude = $GeoAPIRequest.Longitude
        TimeZone  = $GeoAPIRequest.Timezone
        UTC       = $GeoAPIRequest.utc_offset
        Date      = Get-Date -Format g
    }
}

# Define Company Info
$Company = "Lintnotes"
If (!(Get-Item -Path HKLM:\Software\$Company -ErrorAction SilentlyContinue).Name) { New-Item -Path "HKLM:\Software" -Name $Company -ItemType Directory -Force -ErrorAction Stop | Out-Null }

# Collect GeoLocation information
$Results = Get-IPGeolocation
If (!(Get-Item -Path HKLM:\Software\$Company\Geolocation_Info -ErrorAction SilentlyContinue).Name) { New-Item -Path "HKLM:\Software\$Company" -Name "Geolocation_Info" -ItemType Directory -Force -ErrorAction Stop | Out-Null }
If($Results){
    ForEach ($Item in $Results.PSObject.Members | Where-Object MemberType -Like 'NoteProperty') {
        Set-ItemProperty -Path HKLM:\Software\$Company\Geolocation_Info -Name $Item.Name -Value $Item.Value -Force -ErrorAction SilentlyContinue
    }
}