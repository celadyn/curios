<# 

demo censorship: 
    replace all and delete: 


demo from-chat id: 
    19:@unq.gbl.spaces

demo chat message:
    (tms)[1]

demo to-chat id:
    19:@thread.v2

#>

Connect-MgGraph # cannot use application perms, since it's user specific only. unless teams admin ;)


function Import-TeamsChats {
    [Alias('tch')]
    param (
        [parameter()]
        [ValidateRange(1,50)]
        [int]$Count = 20
        ,
        [switch]$Quiet
        ,
        [switch]$Passthru
    )

    $ErrorActionPreference = "Stop"

    if (!$global:TeamsMe) {
        Write-Verbose "Fetching users/me from graph to get user id for later filtering of chat members."
        $global:TeamsMe = [pscustomobject](Invoke-MgGraphRequest -Method get -Uri "https://graph.microsoft.com/v1.0/me") 
    }

    #if (!$ChatList) {
        try {
            $global:TeamsChatObjects = Get-MgChat -Top $Count -ExpandProperty LastMessagePreview,Members -Filter "chatType eq 'oneOnOne' or chatType eq 'group'"

            Write-Host -ForegroundColor Cyan "Found $($TeamsChatObjects.count) chats."

            $global:TeamsChatList = foreach ($Chat in $TeamsChatObjects) {
                switch -regex  ($Chat.ChatType) {
                    "oneOnOne" {
                        $OutSymbol = "1"
                        $OutColor = "Magenta"
                        #old: $ChatMembers = Get-MgChatMember -ChatId $Chat.id | Where-Object {$_.displayname -ne 'Richmond, David'}
                        $ChatMembers = $Chat.Members | Where-Object {$_.additionalproperties['userId'] -ne $TeamsMe.Id}
                        $ChatMembersDisplayName = $ChatMembers.DisplayName -join ";"
                        [pscustomobject]@{
                            Recipient = $ChatMembersDisplayName
                            LastMessage = $Chat.LastMessagePreview.Body.Content
                            ChatID = $Chat.id
                            Chat = $Chat
                        }
                    }

                    "group|meeting" {
                        $OutSymbol = "∞"
                        $OutColor = "Yellow"
                        $ChatMembers = $Chat.Members | Where-Object {$_.additionalproperties['userId'] -ne $TeamsMe.Id}
                        $Recipient = if ([string]::IsNullOrEmpty($Chat.Topic)) {$ChatMembers.DisplayName} else {$Chat.Topic}
                        [pscustomobject]@{
                            Recipient = $Recipient
                            LastMessage = $Chat.LastMessagePreview.Body.Content
                            ChatID = $Chat.id
                            Chat = $Chat
                        }
                    }
                }#switch

                if (!$Quiet) {Write-Host $OutSymbol -ForegroundColor $OutColor -NoNewline}
                Write-Verbose "CHAT: Type:$($Chat.ChatType) | Members: $($ChatMembersDisplayName)"
            }#foreach-chat

            if ($Passthru) {
                $global:TeamsChatList
            }


        } catch {
            throw $_
        }
    #}#if
}#function

function Select-TeamsChatThread {
    [alias('tst')]
    [cmdletbinding()]
    param ()
    
    $SelectedChat = $global:TeamsChatList | Out-GridView -PassThru
    if ($SelectedChat) {
        $global:TeamsSelectedChat = $SelectedChat
        Write-Host -ForegroundColor Green "Selected chat $($SelectedChat.Recipient) - $($SelectedChat.ChatID)"
    } else {
        throw "Please select a chat target!"
    }

}




function Get-DRMgChatMessage {
    [alias('tms')]    
    param (
        [parameter(ValueFromPipelineByPropertyName)]
        [Alias('ChatID')]
        $Chat
        ,
        [parameter()]
        [ValidateRange(1,50)]
        [int]$Count = 5
        ,
        [parameter()]
        [switch]$UseAllImportedChats

    )
    
    begin {
        $ErrorActionPreference = "Stop"

        if (!$Chat -and $global:TeamsSelectedChat) {
            if (!$UseAllImportedChats) {
                $Chat = $global:TeamsSelectedChat
            } else {
                $Chat = $global:TeamsChatList
            }
        } elseif (!$Chat) {
            Write-Error -exception "Please provide a chat target." -Category InvalidArgument
        }

    }#begin

    process {
        foreach ($SingleChat in $Chat) {
            
            switch ($SingleChat) {
                {$_ -is [string]} {
                    $ChatID = $SingleChat
                }

                {$_ -is [pscustomobject]} {
                    $ChatId = $SingleChat.ChatId
                }

                {$_ -is [Microsoft.Graph.PowerShell.Models.MicrosoftGraphChat]} {
                    $ChatID = $SingleChat.Id
                }
                default {throw "No chat ID available from $SingleChat."}
            }#switch

            $ChatMessages = try {Get-MgChatMessage -ChatId $ChatID -top $Count} catch {throw $_}



            if ($ChatMessages) {

                $ChatMessages = $ChatMessages | Sort-Object CreatedDateTime -Descending
    
                foreach ( $Message in $ChatMessages ) {
                    [pscustomobject]@{
                        Chat = $SingleChat
                        ChatID = $ChatID
                        Timestamp = $Message.CreatedDateTime
                        TimeAgo = "$(New-TimeSpan -Start $Message.CreatedDateTime -end ([datetime]::Now))"
                        From = $Message.from.user.displayname
                        Content = $Message.body.content
                    }
                }#foreach-message
            } else {
                Write-Warning "No chat messages found in chat $ChatID"
            }
        }#foreach-pipeline
    }#process

    end {}#end
    
}


function Send-DRMgChatMessage {
    [cmdletbinding(SupportsShouldProcess)]
    param (
        [parameter(ValueFromPipeline)]
        [psobject[]]$Chat
        ,
        [parameter()]
        $Message
    )

    begin {
        if (!$Chat -and $global:TeamsSelectedChat) {
            $Chat = $global:TeamsSelectedChat
        } elseif (!$Chat) {
            Write-Error -exception "Please provide a chat target." -Category InvalidArgument
        }

        $Message = $Message -replace "`r`n","<br>" -replace "`n","<br>" -replace "`r","<br>" 

        $MessageHTML ="<p>$Message</p><p></p><p><i>This message delivered by the <b>DRoBOT</b>.</i></p>"

        $MessageJson = @{
            body = @{
                content = $MessageHTML
                contentType = "html"
            }
        } | ConvertTo-Json
    } 

    process {
        foreach ($SendToChat in $Chat) {

            $NewMgChatMessageSplat = @{
                ChatId = $SendToChat.ChatID
                BodyParameter = $MessageJson
            }

            if ($PSCmdlet.ShouldProcess("to chat '$($SendToChat.Recipient)'","Send teams message with length $($MessageJson.length)")) {
                try {
                    $NewMgChatMessageSplat | Format-List | Out-String | Write-Verbose
                    Write-Host -ForegroundColor Cyan "Sending message to '$($Chat.Recipient)':"
                    Write-Host -ForegroundColor Green "$Message"
                    $SentMessage = New-MgChatMessage @NewMgChatMessageSplat
                    $SentMessage
                } catch {
                    Write-Warning "Unable to send message!"
                    throw $_   
                }
            } else {
                $NewMgChatMessageSplat | Format-List | Out-String | Write-Warning
                Write-Warning "Whatiffed!"
            }
        }
    }

    end {}
}

function Out-Teams {
    [alias('tse')]
    [cmdletbinding(SupportsShouldProcess)]
    param (
        [parameter(ValueFromPipeline,position=0)]
        $Message
        ,
        [parameter()]
        $Chat
    )

    if (!$Chat -and $global:TeamsSelectedChat) {
        $Chat = $global:TeamsSelectedChat
    } elseif (!$Chat) {
        Write-Error -exception "Please provide a chat target." -Category InvalidArgument
    }

    if (!$Message) {
        throw "Please provide a message or pipeline input!"
    } 

    Send-DRMgChatMessage -Chat $Chat -Message $Message -WhatIf
    Read-Host "Confirm?"
    Send-DRMgChatMessage -Chat $Chat -Message $Message
}



break

$message = "<b>USER</b>:`r`n<pre>$inputfull</pre>`r`n`r`n<b>AIREPLY</b>:`r`n<pre>$aireply</pre>"



function Get-RecentTeamsChatMessagesWithSNNumbers {

    [cmdletbinding()]
    [alias('TCSN')]

    param (
        $ChatCount = 5
        ,
        $MessageCount = 20
        ,
        [switch]$RefreshChatStore
    )

    begin {

    }

    process {

        if ($RefreshChatStore) {
            Import-TeamsChats -Count $ChatCount
        }

        $TeamsChats = $global:TeamsChatList | Select-Object -First $ChatCount
        
        
        $ChatMessages = foreach ($TeamsChat in $TeamsChats) {
            Get-DRMgChatMessage -Chat $TeamsChat -Count $MessageCount
        }

        $ChatMessagesWithSNItems = foreach ($Message in $ChatMessages) {
            if (-not [string]::IsNullOrEmpty($Message.content)) {
                $MessageContent = $Message.content -join ""
                $FoundSNItemNumbers = Find-SNItemNumber $MessageContent -Quiet
                if ($FoundSNItemNumbers) {
                    $Message | Add-Member -MemberType NoteProperty -Name "SNItems" -Value $FoundSNItemNumbers -PassThru

                }
            }
        }        
    
        $ChatMessagesWithSNItems
    }
}#function


function Send-SNItemInfoToTeamsChat {
    [cmdletbinding()]

    param (
        $SendToChat
    )

    begin {
        
    }
    
    process {
        
    }
}



<#
Import-TeamsChats -Count 5 -Verbose
Select-TeamsChatThread
(tms | ss content) -join "" | find-snitemnumber | get-snitem | clean-snitemoutput -brief
connect-eeapi servicenow
(tms | ss content) -join "" | find-snitemnumber | get-snitem | clean-snitemoutput -brief
(tms | ss content) -join "" | find-snitemnumber | get-snitem | clean-snitemoutput -brief | s * -ExcludeProperty comment*
$snfounditems = (tms | ss content) -join "" | find-snitemnumber | get-snitem | clean-snitemoutput -brief | s * -ExcludeProperty comment*
$snfounditems
$teamschatobjects
tch
$TeamsSelectedChat
tst
$env:username
tms
tst
tms
tch
tch
tst
tms
tms | select -first 1 | ss content
$LastChatMessage = tms | select -first 1 | ss content
$lastchatmessage
import-module eeservicenow
Find-SNItemNumber $LastChatMessage
$SNItem = Find-SNItemNumber $LastChatMessage | get-snitem | Clean-SNItemOutput -Brief
$snitem
$teamsselectedchat
tse -Message ($snitem | format-list | out-string) -WhatIf
tse -Message ($snitem | format-list | out-string)
#>