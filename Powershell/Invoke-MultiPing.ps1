function Invoke-MultiPing {
	[Alias('mping')]
    [Cmdletbinding()]
    param (
        [Parameter(ValueFromPipeline)]
		[string[]]$Targets
        ,
        [int]$Count = 10
        ,
        [int]$Delay = 1000
        ,
        [Parameter()]
		[Alias('t')]
		[switch]$Continuous
        ,
        [switch]$IncludeGateway
    )

    begin {
        if ("IncludeGateway" -in $MyInvocation.BoundParameters.Keys) {
            $DefaultGateway = Get-NetRoute -DestinationPrefix '0.0.0.0/0' | select -expand NextHop
            $Targets += $DefaultGateway
        }
        if ("Continuous" -in $MyInvocation.BoundParameters.Keys) {
            $Count = 2147483647
        }

    }

    process {

        ### original untested
        <#$PingOutputAllTargets = [pscustomobject]{}
        foreach ($Target in $Targets) {   
            Add-Member -InputObject $PingOutputAllTargets -MemberType NoteProperty -Name $Target -Value "..." -Verbose
        }
        $PingOutputAllTargets | select $Targets
        
        foreach ($Target in $Targets) {
            $PingResult = Test-NetConnection -ComputerName $Target
            $PingResult
            #$PingOutputColumn
        }
        #>
        

        #working with test-netconnection but not ideal does weird other extra stuff
        <#
        for ($i=0;$i -lt $Count;$i++) {
            $PingOutputAllTargets = [pscustomobject]{}
            foreach ($Target in $Targets) {   
                $PingResultTime = $null
                $PingResult = try {Test-NetConnection -ComputerName $Target -ErrorAction Stop} catch {"n/a"}
                $PingResultTime = $PingResult.PingReplyDetails.RoundtripTime
                Add-Member -InputObject $PingOutputAllTargets -MemberType NoteProperty -Name $Target -Value $PingResultTime -Verbose
            }
            $PingOutputAllTargets | select $Targets
        }
        #>

        #final with test-connection which uses wmi ping lol
        for ($i=0;$i -lt $Count;$i++) {
            $PingOutputAllTargets = [pscustomobject]@{
                Timestamp = Get-Date -format FileDateTime
            }
            foreach ($Target in $Targets) {   
                $PingResultTime = $null
                $PingResult = try {Test-Connection -ComputerName $Target -ErrorAction Stop -Count 1} catch {"n/a"}
                $PingResultTime = $PingResult.reply.roundtriptime #ResponseTime #updated in ps7
                Add-Member -InputObject $PingOutputAllTargets -MemberType NoteProperty -Name $Target -Value $PingResultTime -Verbose
            }
            $PingOutputAllTargets | Select-Object $(,"Timestamp" + $Targets) #for output consistency!
            Start-Sleep -Milliseconds $Delay
        }

    }

    end {

    }


}