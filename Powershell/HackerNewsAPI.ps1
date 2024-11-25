## see: https://hn.algolia.com/api
## i hope they keep their api up forever because the HN default api is really annoying to work with

function Get-HNStoriesWithCommentsMatching {
    <#
    .SYNOPSIS 
    Retrieves stories and comments based on comment text search

    .DESCRIPTION
    Retrieves HackerNews stories and comments based on comment text search. Find all the stories that have mentioned your favorite project, then datamine the included comments for sentiment or other insights.

    .PARAMETER QueryString
    The query string to search for in comments.

    .PARAMETER LookbackDays
    The number of days to look back for comments. Default is 7 days.

    .EXAMPLE
    Get-HNStoriesWithCommentsMatching -QueryString "powershell" -LookbackDays 5
    Retrieves stories from Hacker News API with comments matching "powershell" in the last 5 days

    .NOTES
    ♪♫♪ created by david richmond ♪♫♪

    #>

    param (
        $QueryString
        ,
        [int]$LookbackDays = 7
    )

    $StartDate = (Get-Date).AddDays(-$LookbackDays)

    $UnixTimestamp = ([datetimeoffset]($StartDate)).ToUnixTimeSeconds()

    $HNAPIResponse = Invoke-RestMethod "http://hn.algolia.com/api/v1/search_by_date?tags=comment&query=$($QueryString)&numericFilters=created_at_i>$($UnixTimestamp)"

    $HNComments = $HNAPIResponse.hits

    #$HNComments | select updated_at,author,story_title,story_id,comment_text,objectID,parent_id | sort updated_at | Format-List

    $HNComments | % {
        $_| Add-Member -MemberType NoteProperty -Name comment_link -Value "https://news.ycombinator.com/item?id=$($_.objectID)"
    }

    $HNStoryGroups = $HNComments | group story_id


    $StorySummaries = foreach ($HNStoryGroup in $HNStoryGroups) {
    
        $StoryTitle = $HNStoryGroup.Group[0].story_title
        [string]$StoryID = $HNStoryGroup.Group[0].story_id
        [string]$StoryEarliestComment = $HNStoryGroup.Group | sort -property created_at -desc | select -first 1 | select -expandproperty created_at
        $StoryLink = "https://news.ycombinator.com/item?id=$StoryID"

        [pscustomobject]@{
            story_title = $StoryTitle
            story_id = $StoryID
            story_link = $StoryLink
            story_earliest_comment = $StoryEarliestComment
            comments = [pscustomobject]@{hits=$HNStoryGroup.Group}
            commentcount = $HNStoryGroup.count
        }
    }

    $StorySummaries

}