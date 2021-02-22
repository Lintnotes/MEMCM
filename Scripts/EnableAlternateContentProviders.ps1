
$siteCode = "NA1"
$siteServer = "USPAMECM01"
$acp = 
@"
<AlternateDownloadSettings SchemaVersion="1.0"><Provider Name="NomadBranch"><Data><ProviderSettings /><rh /><pc>1</pc></Data></Provider></AlternateDownloadSettings>
"@
$MaxWorkRate = 80

new-eventlog -source 1E -logname Application -erroraction silentlycontinue

$Exclude = @("Configuration Manager Client Package","Configuration Manager Client Piloting Package")
$Packages = Get-WmiObject -Namespace root\sms\site_$SiteCode -Class SMS_Package | Where-Object {$_.Name -notin $Exclude}


Foreach($Package in $Packages){
$Package = [wmi]"$($Package.__Path)"
if ($Package.AlternateContentProviders -notmatch "nomad") {
    Write-Host "Enabling acp for $($Package.Name)"
    write-eventlog -logname Application -source 1E -eventID 100 -entrytype Information -message "Enabling default Nomad Branch settings on package $pkgID"
    $Package.AlternateContentProviders = $acp
    $Package.Put() | Out-Null
}
else #acp already enabled, checking settings
{
    #check to see if work rate is configured properly
    $pkg2xml = [xml] $Package.AlternateContentProviders

    if ($pkg2xml.AlternateDownloadSettings.Provider.data.wr -ne $null) {
        if ($pkg2xml.AlternateDownloadSettings.Provider.data.wr -gt $MaxWorkRate) {
        Write-Host "non-standard config Resetting acp default settings"
        write-eventlog -logname Application -source 1E -eventID 100 -entrytype Information -message "Non-standard Setting Configured - Re-Enabling default Nomad Branch settings on package $pkgID and resetting workrate to 80"
        $Package.AlternateContentProviders = $acp
        $Package.Put() | Out-Null
        
        }
     else
     {
        
        #"acp already enabled, and work rate is acceptable"
     }
        
     }
     else
     {
        #"wr is Null, which is considered acceptable"
     }
}
}