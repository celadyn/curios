function aip {
    <#
        .SYNOPSIS
        This is **Experimental** AI function
        .DESCRIPTIONW
        AI function that you can pipe all sorts of things into and get back a completion

        .EXAMPLE
        ai "list of planets only names as json" |
        .EXAMPLE
        ai "list of planets only names as json" | ai 'convert to  xml'
        .EXAMPLE
        ai "list of planets only names as json" | ai 'convert to  xml' | ai 'convert to  powershell'
        .EXAMPLE
        git status | ai "create a detailed git message"
    #>
    [CmdletBinding()]
    param(
        $prePrompt
        ,
        [Parameter(ValueFromPipeline = $true)]
        $pipelineInput
        ,
        $postPrompt
        ,
        [ValidateRange(0,2)]
        [decimal]$temperature = 0.0
        ,
        $max_tokens = 1024
    )

    Begin {
        [System.Collections.ArrayList]$lines = @()
    }

    Process {
        $lines += $pipelineInput
    }

    End {
        $fullPrompt = @"
$($prePrompt)
$(($lines | Out-String).Trim())
$($postPrompt)

"@

        Write-Verbose $fullPrompt.Trim()

        (Get-GPT3Completion -prompt $fullPrompt.Trim() -max_tokens $max_tokens -temperature $temperature).Trim()
    }
}


