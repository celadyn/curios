<#

A PowerShell module for using svcl.exe from NirSoft
SVCL docs: https://www.nirsoft.net/utils/sound_volume_view.html#command_line

Primarily using this to be able to mute certain extremely annoying apps from the PS cli.

#>


using namespace System
using namespace System.Management.Automation


function Invoke-SVCLCommand {
    [cmdletbinding()]
    [alias('svl')]
    param (
        [Parameter(ValueFromRemainingArguments)]
        [string]$Command
        #,
        #[string]$SVCLExePath = "$env:Onedrive\Scripts\AHK\ahkl\svcl-x64\svcl.exe"
    )

    $SVCLPath = $SVCLExePath = "$env:Onedrive\Scripts\AHK\ahkl\svcl-x64\svcl.exe"
    
    $SVCLExecutableValidation = Test-Path $SVCLPath

    if ($SVCLExecutableValidation) {
        Write-Verbose "SVCL.exe found at $SVCLPath"
        Write-Verbose "Executing command: svcl.exe $Command"
        $SplitCommand = $Command -split " "
        &$SVCLPath $SplitCommand
    } else {
        Write-Error "SVCL.exe not found at '$SVCLPath'. Please manually specify path or install svcl from nirsoft."
    }

}

function Get-SVCLAllColumns {
    [cmdletbinding()]
    param (
        [string]$Name
        ,
        [switch]$Raw
    )

    $SoundLevelsRaw = Invoke-SVCLCommand /scomma "" 

    if ($Raw) {
        return $SoundLevelsRaw
    }
    
    #replacing weird chars in first column wtf
    $SoundLevelsRaw[0] = $SoundLevelsRaw[0] -replace '[^A-Za-z,]*'
    
    $SoundLevels = $SoundLevelsRaw | ConvertFrom-CSV

    $SoundLevels

}

function Get-SVCLLevel {
    [cmdletbinding()]
    param (
        $Name
        ,
        [ValidateSet('Capture','Render')]
        $Direction
        ,
        [ValidateSet('Device','Application','Subunit')]
        $Type
    )

    $SoundLevels = Get-SVCLAllColumns

    if ($Name) {
        #Invoke-SVCLCommand /stdout /GetPercent "$Name" -Verbose:$VerbosePreference | ConvertFrom-CSV
        $SoundLevels = $SoundLevels | ? {$_.Name -match $Name}
    } 
    
    if ($Direction) {
        $SoundLevels = $SoundLevels | ? {$_.Direction -eq $Direction}
    }
    
    if ($Type) {
        $SoundLevels = $SoundLevels | ? {$_.Direction -eq $Type}
    }
    
    if (($SoundLevels | Measure-Object).Count -gt 0) {
        $SoundLevels
    } else {
        Write-Host -ForegroundColor DarkYellow "No results found for $Name."
    }
    
}

function Set-SVCLLevel {
    [cmdletbinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(ValueFromPipeline)]
        [psobject[]]$SVCLObject
        ,
        [Parameter()]
        [ValidateSet('Switch','Mute','Unmute','SetVolume')]
        $Action = "SetVolume"
        ,
        [Parameter()]
        #validatescript - check between 1 and 100
        [ValidateRange(1,100)]
        [int]$VolumePercent = $null
        ,
        [Parameter()]
        [ValidateSet('Name','CommandLineFriendlyID','ItemID','ProcessID')]
        $IdentifyBy = 'ProcessID'
    )

    begin {
        Write-Verbose "Action: $Action"
        Write-Verbose "IdentifyBy: $IdentifyBy"
    }

    process {
        foreach ($SoundObject in $SVCLObject) {
            if ($PSCmdlet.ShouldProcess("Execute $Action on '$($SoundObject.Name) - $($SoundObject.$IdentifyBy)'"))  {
                #$SVCLOutput = Invoke-SVCLCommand /stdout /$Action """$($SoundObject.$IdentifyBy)""" #quotes
                $SVCLOutput = Invoke-SVCLCommand /stdout /$Action $($SoundObject.$IdentifyBy) $VolumePercent #noquotes
                Write-Host "$Action result: $SVCLOutput"
            } else {
                Write-Warning "NOT EXECUTING: Invoke-SVCLCommand /stdout /$Action ""$($SoundObject.$IdentifyBy)"" $VolumePercent"
            }
        }
    }

    end {}
}


function Mute-SVCLApp {
    [Alias('Unmute-SVCLApp','Unmute','Mute')]
    [cmdletbinding(SupportsShouldProcess,DefaultParameterSetName='Name')]
    param (
        [Parameter(ValueFromPipeline,ParameterSetName='Process',position=0)]
        [System.Diagnostics.Process[]]$Process
        ,
        [Parameter(ValueFromPipeline,ParameterSetName='Name',position=0)]
        [string[]]$ProcessName
    )

    begin {

        Write-Verbose "ParameterSetName: $($PSCmdlet.ParameterSetName)"
        Write-Verbose "Invoked as: $($MyInvocation.InvocationName)"
        
        switch -regex ($MyInvocation.InvocationName) {
            'Mute' { $Action = 'Mute' }
            'Unmute' { $Action = 'Unmute' }
        }

        Write-Verbose "Action: $Action"

        ### bound parameter shortcuts
        foreach ($BoundParameter in $MyInvocation.BoundParameters.Keys) {
            $BPShortcut = Set-Variable -Name "BP_$BoundParameter" -Value $true -PassThru -whatif:$false
            Write-Verbose "BOUNDPARAM FOUND -- Set $($BPShortcut.Name) to $($BPShortcut.Value) -- actual value: $($MyInvocation.BoundParameters["$BoundParameter"])"
        }
        
        $SoundLevels = Get-SVCLLevel -Direction Render
        $CorrespondingProcessLevels = [system.collections.generic.list[psobject]]::new()

    }

    process {

        $Names = switch ($PSCmdlet.ParameterSetName) {
            'Process' { $Process.ProcessName }
            'Name' { $ProcessName }
        }

        Write-Verbose "Names: $Names"
        foreach ($Name in $Names) {
            $FoundLevels = $SoundLevels | Where-Object {$_.Name -match $Name -or ($_.Name -replace " ","") -match $Name}
            $FoundLevels | Foreach-Object {$CorrespondingProcessLevels.Add($_)}
        }
    }

    end {
        $UniqueLevels = $CorrespondingProcessLevels | Sort-Object -Property ProcessID -Unique
        Write-Verbose "Found $($FoundLevels.Count) levels for '$Name'"
        foreach ($UniqueLevel in $UniqueLevels) {
            if ($true) { #($PScmdlet.ShouldProcess("App '$Name' with $($FoundLevels.count) devices:`r`n  $($FoundLevels.'Device Name' -join "`r`n  ")","$Action")) {
                <#
                foreach ($Level in $FoundLevels) {
                    Invoke-SVCLCommand /stdout /Mute $_.'Item ID' -Verbose:$VerbosePreference
                }
                #>
                Set-SVCLLevel -SVCLObject $FoundLevels -Action $Action -IdentifyBy ProcessID -Verbose:$VerbosePreference -WhatIf:$WhatIfPreference
            }
        }

    }
}



break

$SoundLevels = . "$env:Onedrive\Scripts\AHK\ahkl\svcl-x64\svcl.exe" /scomma "" | ConvertFrom-CSV

$SoundLevels | ? {$_.Name -match "Discord"} | % {}

<#
class ProcessTransform : ArgumentTransformationAttribute {
    [Object] Transform([EngineIntrinsics] $engineIntrinsics, [Object] $inputData) {
        if ($inputData -is [Diagnostics.Process]) {
            return $inputData
        }

        if ($inputData -is [int]) {
            return [Diagnostics.Process]::GetProcessById($inputData)
        }

        return [Diagnostics.Process]::GetProcessesByName($inputData)
    }
}

function Do-Thing {
    param(
        [Parameter(ValueFromPipeline)]
        [ProcessTransform()]
        [Diagnostics.Process[]] $Process
    )
    process { $Process }
}

$proc = Get-Process | Get-Random -Count 3
$proc[0], $proc[1].Id, $proc[2].Name | Do-Thing


#>

