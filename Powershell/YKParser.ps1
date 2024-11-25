function Invoke-YKManCommand {
    [cmdletbinding()]
    [alias('yk')]
    param (
        [string]$Command
        ,
        [string]$YKManExePath = "C:\Program Files\Yubico\YubiKey Manager\ykman.exe"
    )

    $YKMANPath = $YKManExePath
    
    $YKMANTest = Test-Path $YKMANPath

    if ($YKMANTest) {
        Write-Verbose "ykman.exe found at $YKMANPath"
        Write-Verbose "Executing command: $Command"
        $SplitCommand = $Command -split " "
        &$YKManpath $SplitCommand
    } else {
        Write-Error "YubiKey Manager not found at '$YKMANPath'. Please manually specify path or install YubiKey Manager."
    }

}

function Get-YKDevices {
    [cmdletbinding()]
    param (
        [parameter()]
        [switch]$ShowHelp
    )
    if (-not $ShowHelp) {
        Invoke-YKManCommand 'list --serials'
    } else {
        Invoke-YKManCommand 'list --serials --help'
    }
}

function Get-YKDeviceInfo {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline)]
        [string[]]$Serial
        ,
        [parameter()]
        [validateset('Raw','Parsed')]
        [string]$OutputMode = "Parsed"
    )

    begin {}
    
    process {
        foreach ($SerialNumber in $Serial) {
            $DeviceInfoRaw = Invoke-YKManCommand "--device $SerialNumber info"
            $DeviceInfoObject = [pscustomobject]@{
                Serial = $SerialNumber
                DeviceInfo = $DeviceInfoRaw
            }

            if ($OutputMode -eq "Parsed") {
                $DeviceInfoParsed = Parse-YKDeviceInfo $DeviceInfoObject
            }

            $Output = switch ($OutputMode) {
                "Raw"    {$DeviceInfoRaw}
                "Parsed" {$DeviceInfoParsed}
            }

            return $Output
           
        }#foreach-serial
    }#process

    end {}
}

function Parse-YKDeviceInfo {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [psobject[]]$DeviceInfoObject
    )

    begin {

    }

    process {
        foreach ($InfoObject in $DeviceInfoObject) {
            $DeviceInfoProperties = [system.collections.generic.list[psobject]]::new()
            $DeviceInfoApplications = [system.collections.generic.list[psobject]]::new()
    
            foreach ($Line in $InfoObject.DeviceInfo) {
                #check to see if we're at the separator line - if so, 
                if ([string]::IsNullOrEmpty($Line)) {
                    $PropertyVsApplicationSeparatorLineFound = $true
                    continue
                }

                #now start adding to props list, which list varies depending on if we've passed the separator or not
                if (-not $PropertyVsApplicationSeparatorLineFound) {
                    $DeviceInfoProperties.Add($Line)
                } else {
                    $DeviceInfoApplications.Add($Line)
                }
        
            }

            $DIPropertiesHashtable = [ordered]@{}
            foreach ($PropertyLine in $DeviceInfoProperties) {
                Write-Verbose "INFO: $PropertyLine"
                if ($PropertyLine -match ": ") {
                    $SplitPropertyLine = $PropertyLine -split ": "
                    $PropertyName = (Get-Culture).TextInfo.ToTitleCase($SplitPropertyLine[0]) -replace " ",""
                    $PropertyValue = $SplitPropertyLine[1]
                    $DIPropertiesHashtable.Add($PropertyName,$PropertyValue)
                } else {
                    $MiscCounter++
                    $DIPropertiesHashtable.Add("Misc_$MiscCounter",$PropertyLine)
                }
            }

            $DIApplicationsHashtable = [ordered]@{}
            foreach ($AppLine in $DeviceInfoApplications) {
                Write-Verbose "APP: $AppLine"
                #if ($AppLine -match "^Applications") {
                
                if (-not $AppColumnInfo) {
                    $USBColumnIndex = $AppLine.IndexOf("USB")
                    $NFCColumnIndex = $AppLine.IndexOf("NFC")
                    $AppColumnInfo = [pscustomobject]@{
                        AppNameColumnStart = 0
                        AppNameColumnEnd   = $USBColumnIndex - 1
                        USBColumnStart     = $USBColumnIndex
                        USBColumnEnd       = $NFCColumnIndex - 1
                        NFCColumnStart     = $NFCColumnIndex
                        NFCColumnEnd       = 999
                    }
                    continue
                }
                
                $AppName = ($AppLine[($AppColumnInfo.AppNameColumnStart)..($AppColumnInfo.AppNameColumnEnd)] -join "").Trim()
                $USBStatus = ($AppLine[($AppColumnInfo.USBColumnStart)..($AppColumnInfo.USBColumnEnd)] -join "").Trim()
                $NFCStatus = ($AppLine[($AppColumnInfo.NFCColumnStart)..($AppColumnInfo.NFCColumnEnd)] -join "").Trim()

                $DIApplicationsHashtable.Add($AppName,"USB_$USBStatus;NFC_$NFCStatus")

                #$SplitAppLine = $AppLine -replace "Not available","NotAvailable" -split "\s+"
                #$DIApplicationsHashtable.Add($SplitAppLine[0],"USB_$($SplitAppLine[1]);NFC_$($SplitAppLine[2])")
            }

            $DIPropertiesHashtable.Add("Applications",$DIApplicationsHashtable)
            [pscustomobject]$DIPropertiesHashtable
    
            
        }
    }

    end {
        
    }

}


function Parse-YKDeviceInfoOld {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string[]]$DeviceInfo
    )

    begin {
        $DeviceInfoList = [system.collections.generic.list[psobject]]::new()
        $DeviceInfoCollector = [system.collections.generic.list[psobject]]::new()
        $DeviceInfoList.Add($DeviceInfoCollector)

    }

    process {
        foreach ($PropertyLine in $DeviceInfo) {
            $DeviceInfoCollector.Add($PropertyLine)
            
            if ($PropertyLine -match "Device type") {
                $DeviceInfoCollector = [system.collections.generic.list[psobject]]::new()
                $DeviceInfoList.Add($DeviceInfoCollector)
            }
        }
    }

    end {


        <#

        $DeviceInfoProperties = [system.collections.generic.list[psobject]]::new()
        $DeviceInfoApplications = [system.collections.generic.list[psobject]]::new()

        foreach ($SingleDeviceInfo in $DeviceInfoList) {
            foreach ($Line in $SingleDeviceInfo) {
                #check to see if we're at the separator line - if so, 
                if ([string]::IsNullOrEmpty($Line)) {
                    $PropertyVsApplicationSeparatorLineFound = $true
                }

                #now start adding to props list, which list varies depending on if we've passed the separator or not
                if (-not $PropertyVsApplicationSeparatorLineFound) {
                    $DeviceInfoProperties.Add($Line)
                } else {
                    $DeviceInfoApplications.Add($Line)
                }
        
            }

            foreach ($PropertyLine in $DeviceInfoProperties) {
                Write-Verbose "INFO: $PropertyLine"
            }


            foreach ($AppLine in $DeviceInfoApplications) {
                Write-Verbose "APP: $APPLine"
            }
        }
        
        #>

        $DeviceInfoList
        
    }

}
