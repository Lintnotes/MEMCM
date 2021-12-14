<#
.SYNOPSIS
    Converts Windows Server Editions from Standard to Datacenter.
.DESCRIPTION
    This script will verify Supported Operating Systems and Editions and run DISM to convert the Windows Edition to Datacenter.
.EXAMPLE
    ConvertTo-WindowsServerDataCenterEdition.ps1
.NOTES
    FileName:   ConvertTo-WindowsServerDataCenterEdition.ps1
    Author:     Brandon Linton
    Contact:    @Lintnotes
    Created:    2021-12-13
    Updated:    2021-12-14
    Version History:
        1.0.0 - (2021-12-13) - Script Created
        1.0.1 - (2021-12-14) - Bug Fixes and additional logging.

Disclaimer. The sample scripts are not supported under any Microsoft standard support program or service. 
The sample scripts are provided AS IS without warranty of any kind. 
Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.
#>


Function Log-Message() {
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Value added to the log file.")] 
        [ValidateNotNullOrEmpty()] 
        [string] $Value,

        [Parameter(Mandatory = $true, HelpMessage = "Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")] 
        [ValidateNotNullOrEmpty()] 
        [ValidateSet("1", "2", "3")] 
        [string]$Severity,

        [Parameter(Mandatory = $false, HelpMessage = "Name of the log file that the entry will written to.")]
        [ValidateNotNullOrEmpty()]
        [string]$FileName = "ConvertTo-WindowsServerDataCenterEdition.log"
    )
 
    Try {
        #Set the Location of the Log
        If(!(Test-Path $ENV:WINDIR\Logs\Software)){
            New-Item -ItemType Directory -Path $ENV:WINDIR\Logs\Software -Force | Out-Null
        }
        
        $Script:LogFilePath = Join-Path  -Path "$ENV:WINDIR\Logs\Software" -ChildPath $FileName

        # Construct time stamp for log entry
        if (-not (Test-Path -Path 'variable:global:TimezoneBias')) {
            [string]$global:TimezoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
            if ($TimezoneBias -match "^-") {
                $TimezoneBias = $TimezoneBias.Replace('-', '+')
            }
            else {
                $TimezoneBias = '-' + $TimezoneBias
            }
        }
        $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), $TimezoneBias)

        #Get the current date
        $Date = (Get-Date -Format "MM-dd-yyyy")
 
        # Construct context for log entry
        $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
		
        # Construct final log entry
        $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""DISM"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
		 
        # Add value to log file
        try {
            Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
        }
        catch [System.Exception] {
            Write-Warning -Message "Unable to append log entry to ConvertTo-WindowsServerDataCenterEdition.log file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
        }
 
        Switch ($Severity){
            1 {$Color = 'Green'}
            2 { $Color = 'Yellow'}
            3 { $Color = 'Red'}
        }
        Write-Host "Message: '$Value'" -ForegroundColor $Color
    }
    Catch {
        Write-Host -f Red "Error:" $_.Exception.Message
    }
}

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

#Call the function to Log messages and start main routine
Clear-Host
Log-Message "Script Execution Started" -Severity 1
Log-Message "Script Logging: $($LogFilePath)" -Severity 1
Log-Message "Gathering Data Please be patient..." -Severity 1
$Script:OS = (Get-WmiObject Win32_OperatingSystem).Caption
$Script:OSBuild = (Get-WmiObject Win32_OperatingSystem).BuildNumber
$Script:CurrentEdition = (Dism /Online /Get-CurrentEdition | Select-String "Current Edition : ").ToString().Split(":")[1].Trim()
$Script:TargetEditions = (Dism /Online /Get-TargetEditions | Select-String "Target Edition : ").ToString().Split(":")[1].Trim()

Switch -Wildcard ($OS){
    "*Server 2012 R2*" { $KMSClientSetupKey = 'W3GGN-FT8W3-Y4M27-J84CP-Q3VJ9' ; $SupportedOS = $True }
    "*Server 2016*"    { $KMSClientSetupKey = 'CB7KF-BWN84-R7R2Y-793K2-8XDDG' ; $SupportedOS = $True }
    "*Server 2019*"    { $KMSClientSetupKey = 'WMDGN-G9PQG-XVVXX-R3X43-63DFG' ; $SupportedOS = $True }
    "*Server 2022*"    { $KMSClientSetupKey = 'WX4NM-KYWYW-QJJR4-XV3QB-6VM33' ; $SupportedOS = $True }
    Default            { $KMSClientSetupKey = $null                           ; $SupportedOS = $False}
}

If($SupportedOS -eq $True){
    Log-Message "Detected Supported Operating System: $($OS)" -Severity 1
    Log-Message "Detected Operating System Version: $($OSBuild)" -Severity 1
    If ($CurrentEdition -eq 'ServerStandard') {
        Log-Message "Current Edition Detected is: $($CurrentEdition)" -Severity 1
        If ($TargetEditions -eq 'ServerDataCenter') {
            Log-Message "Target Edition to upgrade to is: $TargetEditions" -Severity 1
            Log-Message "Running DISM to Upgrade $ENV:COMPUTERNAME from $($CurrentEdition) to $($TargetEditions)" -Severity 1
            Log-Message "Starting Installation..." -Severity 1
            Log-Message "Additional logging can be found in: $ENV:WINDIR\Logs\DISM\dism.log" -Severity 1
            Log-Message "This will likely take some time - Please be patient!" -Severity 2
            $Result = Dism /Online /Set-Edition:ServerDataCenter /ProductKey:$KMSClientSetupKey /AcceptEula /NoRestart
            If ($LASTEXITCODE -eq '3010' -or $LASTEXITCODE -eq '0') {
                Log-Message "Edition Upgrade Completed Successfully, Reboot is required to process changes." -Severity 1
            }
            Else{
                Log-Message "Edition Upgraded Failed on $($ENV:Computername) with the following Exit Code: $($LASTEXITCODE)" -Severity 3
                Log-Message "$_.Exception.Message" -Severity 3
            }
        }
        Else {
            Log-Message "Target Edition Detected is: $($TargetEditions) NOT Supported Script Execution Stopping..." -Severity 3
            Log-Message "Additional logging can be found in: $ENV:WINDIR\Logs\DISM\dism.log" -Severity 2
            Break
        }
    }
    Else {
        Log-Message "Current Edition Detected is: $($CurrentEdition) NOT Supported Script Execution Stopping..." -Severity 3
        Log-Message "Additional logging can be found in: $ENV:WINDIR\Logs\DISM\dism.log" -Severity 2
        Break
    }
}
Else{
    Log-Message "Unsupported Operating System: $($OS) Detected Script Execution Stopping..." -Severity 3
    Break
}

Log-Message "Script Execution Completed" -Severity 1