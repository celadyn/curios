# convert the above json to a proper powershell-originated hashtable+array construction
function Get-LMStudioCompletion {
    [cmdletbinding()]
    [Alias('lm')] 
    param (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromRemainingArguments,Position=0)]
        [string]$UserPrompt
        ,
        [string]$SystemPrompt = "You are a helpful assistant. Answer without overly speculating."
        ,
        [string]$Model = "codestral-22b-v0.1"
        ,
        [switch]$Stream
    )

    begin {

    }
    process {
        foreach ($Prompt in $UserPrompt) {

            $Body = @{
                "model" = $Model
                "messages" = @(
                    @{
                        "role" = "system"
                        "content" = $SystemPrompt
                    },
                    @{
                        "role" = "user"
                        "content" = $Prompt
                    }
                )
                "temperature" = 0.7
                "max_tokens" = -1
                "stream" = [bool]$Stream
            }

            Write-Verbose "Prompt: $Prompt"
            $IRMSplat = @{
                Uri = "http://localhost:1234/v1/chat/completions"
                Method = "Post"
                ContentType = "application/json"
                Body = (ConvertTo-Json -Compress $Body)
            }
            $IRMSplat | Format-List | Out-String | Write-Debug

            $StartTime = [datetime]::Now
            $Response = Invoke-RestMethod @IRMSplat
            $EndTime = [datetime]::Now
            $CalcTimeDuration = ($EndTime - $StartTime).TotalSeconds
            
            $TokensPerSecond = $Response.usage.completion_tokens / $CalcTimeDuration

            $Response.choices.message.content
            Write-Host -ForegroundColor Green "Time: [$($CalcTimeDuration)] | Usage: P:[$($response.usage.prompt_tokens)] C:[$($response.usage.completion_tokens)] T:[$($response.usage.total_tokens)] | TPS: [$($TokensPerSecond)]"
        }#foreach
    }#process
}#function-Get-LMStudioCompletion

break

########### use cases! 

#json system prompt testing

$LMSplat = @{
    #Model = "qwen2.5-7b-instruct"
    Debug = $True
    SystemPrompt = "Always answer in JSON form. DO NOT emit ANY other text outside of the JSON block. Do NOT add any codeblock `s - start with { and end with }. No exceptions.
    Breaking the question into a series of smaller questions.  Include in the answer array a 'assumptions' section listing out the potential question-asker's assumptions related to the topic (without being philosophical)."
}

lm @LMSplat "is the YCBCR color space the same as the LAB colorspace, or are they equivalent as references in some way? explain from moderate color theory understanding level. "


# hackernews specific term sentinemt analysis

$LMSplat = @{
    #Model = "qwen2.5-7b-instruct"
    #Debug = $True
    Verbose = $true
    SystemPrompt = "Always answer in JSON form. DO NOT emit ANY other text outside of the JSON block. Do NOT add any codeblock `s - start with { and end with }. No exceptions.
    Analyze incoming text and output response using the following schema: { 'author':  <author>, 'CommentGeneralTopic': <two to three word categorization>, 'sentimentAboutPowershell': <Mandatory -- Positive/Neutral/Negative/UnableToDetermine>, ;BestSentimentEvidenceSnippet: <small part of text which best supports the sentiment determination>, 'nameUsedForPowershell': <this is how the author refers to powershell, could be an abbreviation or just the word. it will ALWAYS be present>, 'TypeOfReferenceToPowershell': <Discussion/Mention>}."
}

$PWSHCommentsLastWeek = Get-HNStoriesWithCommentsMatching -QueryString "powershell" -LookbackDays 7 -LookbackAnchorDaysAgo 0 -debug -brief

$Analysis = $PWSHCommentsLastWeek | select comment_text,author | % {$_ | ConvertTo-Json | lm @LMSplat} 
$CJ = $Analysis -replace '```(json)?' | ConvertFrom-Json

$CJ | fl