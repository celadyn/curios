function ConvertFrom-TextTable {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$InputText
    )
    
    begin {
        $TextLines = [System.Collections.Generic.List[string]]::new()
    }
    
    process {
        foreach ($CurrentLine in $InputText) {
            $TextLines.Add($CurrentLine)
        }
    }
    
    end {
        # Need at least a header row
        if ($TextLines.Count -lt 1) {
            throw "Input must contain at least a header row"
        }

        $HeaderRow = $TextLines[0]
        
        # Find column boundaries by detecting where columns start
        $ColumnStartPositions = [System.Collections.Generic.List[int]]::new()
        $PreviousCharacter = ' '
        
        for ($CharIndex = 0; $CharIndex -lt $HeaderRow.Length; $CharIndex++) {
            if ($PreviousCharacter -eq ' ' -and $HeaderRow[$CharIndex] -ne ' ') {
                $ColumnStartPositions.Add($CharIndex)
            }
            $PreviousCharacter = $HeaderRow[$CharIndex]
        }
        
        # Extract column headers
        $ColumnHeaders = [System.Collections.Generic.List[string]]::new()
        for ($ColumnIndex = 0; $ColumnIndex -lt $ColumnStartPositions.Count; $ColumnIndex++) {
            $StartPosition = $ColumnStartPositions[$ColumnIndex]
            $EndPosition = if ($ColumnIndex -lt $ColumnStartPositions.Count - 1) {
                $ColumnStartPositions[$ColumnIndex+1] - 1
            } else {
                $HeaderRow.Length
            }
            
            $HeaderText = $HeaderRow.Substring($StartPosition, $EndPosition - $StartPosition).Trim()
            $ColumnHeaders.Add($HeaderText)
        }
        
        # Process data rows
        $ResultObjects = [System.Collections.Generic.List[PSObject]]::new()
        for ($LineIndex = 1; $LineIndex -lt $TextLines.Count; $LineIndex++) {
            $DataLine = $TextLines[$LineIndex]
            if ([string]::IsNullOrWhiteSpace($DataLine)) { continue }
            
            $ParsedObject = [ordered]@{}
            
            for ($ColumnIndex = 0; $ColumnIndex -lt $ColumnHeaders.Count; $ColumnIndex++) {
                $StartPosition = $ColumnStartPositions[$ColumnIndex]
                $EndPosition = if ($ColumnIndex -lt $ColumnStartPositions.Count - 1) {
                    $ColumnStartPositions[$ColumnIndex+1]
                } else {
                    $DataLine.Length
                }
                
                if ($StartPosition -lt $DataLine.Length) {
                    $FieldWidth = [Math]::Min($EndPosition - $StartPosition, $DataLine.Length - $StartPosition)
                    $FieldContent = $DataLine.Substring($StartPosition, $FieldWidth).Trim()
                } else {
                    $FieldContent = ""
                }
                
                $ParsedObject[$ColumnHeaders[$ColumnIndex]] = $FieldContent
            }
            
            $ResultObjects.Add([PSCustomObject]$ParsedObject)
        }
        
        return $ResultObjects
    }
}


function ProcessSectionContent {
    param([string[]]$SectionLines)
    
    $SectionProperties = [ordered]@{}
    $ValueStartPosition = -1
    
    # First, determine the column structure by finding the first line with a clear property-value pattern
    foreach ($Line in $SectionLines) {
        
        $LineToCheckForValueColumnIndex = $Line.TrimStart()
        Write-Debug "Processing:`r`n$LineToCheckForValueColumnIndex"

        # Skip empty lines
        if ([string]::IsNullOrWhiteSpace($LineToCheckForValueColumnIndex)) { continue }
        
        # Look for a line that has multiple spaces between words - potential property-value format
        if ($LineToCheckForValueColumnIndex -match "\S+(\s{2,})") {
            # Find the position of the first double space, which likely indicates 
            # the end of the property name and start of the value
            $Match = [regex]::Match($LineToCheckForValueColumnIndex, "\s{2,}\S(.)")
            if ($Match.Success) {
                # Calculate the position of the value start in the original line
                $ValueStartPosition = $Match.groups[1].index #$Line.Length - $LineToCheckForValueColumnIndex.Length + $Match.Index + 1
                Write-Debug "$("_" * (0..($ValueStartPosition-1))[-1])^"
                Write-Debug "  -> Detected value start position at column $ValueStartPosition"
                
            }
        }
    }


    
    # If we couldn't detect a property-value pattern, treat everything as text
    if ($ValueStartPosition -lt 0) {
        Write-Debug "  -> No clear property-value pattern detected, treating all as text"
        $SectionProperties["Text"] = ($SectionLines | ForEach-Object { $_.Trim() }) -join "`n"
        return $SectionProperties
    }
    
    # Process each line using the detected column structure
    foreach ($Line in $SectionLines) {
        if ([string]::IsNullOrWhiteSpace($Line)) { continue }
        
        $TrimmedLine = $Line.Trim()
        Write-Debug "  -> Processing line: '$TrimmedLine'"
        
        # Check if the line is long enough to have both property and value
        if ($Line.Length -gt $ValueStartPosition) {
            $PropertyName = $Line.Substring(0, $ValueStartPosition).Trim().TrimEnd()
            $PropertyValue = $Line.Substring($ValueStartPosition).Trim()
            
            if (-not [string]::IsNullOrWhiteSpace($PropertyName)) {
                Write-Debug "    -> Found property: '$PropertyName' = '$PropertyValue'"
                
                # Handle multiple values with same property name
                if ($null -ne $SectionProperties[$PropertyName]) {
                    # If it's already a list, add to it
                    if ($SectionProperties[$PropertyName] -is [System.Collections.Generic.List[string]]) {
                        $SectionProperties[$PropertyName].Add($PropertyValue)
                    }
                    # If it's a single string, convert to list and add
                    else {
                        $ValueList = [System.Collections.Generic.List[string]]::new()
                        $ValueList.Add($SectionProperties[$PropertyName])
                        $ValueList.Add($PropertyValue)
                        $SectionProperties[$PropertyName] = $ValueList
                    }
                }
                else {
                    $SectionProperties[$PropertyName] = $PropertyValue
                }
                continue
            }
        }
        
        # If we couldn't parse it as property-value, treat as continuation text
        Write-Debug "    -> Processing as free text"
        if ($null -ne $SectionProperties["Text"]) {
            $SectionProperties["Text"] += "`n" + $TrimmedLine
        }
        else {
            $SectionProperties["Text"] = $TrimmedLine
        }
    }
    
    return $SectionProperties
}


function ConvertFrom-OllamaModelInfo {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [AllowEmptyString()]
        [string[]]$InputText
    )
    
    begin {
        $TextLines = [System.Collections.Generic.List[string]]::new()
    }
    
    process {
        foreach ($CurrentLine in $InputText) {
            $TextLines.Add($CurrentLine)
        }
    }
    
    end {
        if ($TextLines.Count -lt 1) {
            throw "Input is empty"
        }

        $Result = [ordered]@{}
        $CurrentSection = $null
        $CurrentProperties = $null
        $CurrentSectionLines = @()
        $CurrentValueStartPosition = -1
        
        # Process all lines, grouping them by sections
        for ($i = 0; $i -lt $TextLines.Count; $i++) {
            $Line = $TextLines[$i]
            
            # Debug output to show each line as it's processed
            Write-Debug "Processing line: '$Line'"
            
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($Line)) { 
                Write-Debug "  -> Skipping empty line"
                continue 
            }
            
            # Check if this is a section header (indented with exactly 2 spaces)
            if ($Line -match "^  \S" -and $Line -notmatch "^    ") {
                # Process the previous section before starting a new one
                if ($CurrentSection -ne $null -and $CurrentSectionLines.Count -gt 0) {
                    $Result[$CurrentSection] = ProcessSectionContent -SectionLines $CurrentSectionLines -Debug:$true
                }
                
                # Start new section
                $CurrentSection = $Line.Trim()
                Write-Debug "  -> Found section header: '$CurrentSection'"
                $CurrentSectionLines = @()
                $CurrentValueStartPosition = -1
                continue
            }
            
            # Add the line to the current section if we're in one
            if ($CurrentSection -ne $null) {
                $CurrentSectionLines += $Line
            }
        }
        
        # Process the last section
        if ($CurrentSection -ne $null -and $CurrentSectionLines.Count -gt 0) {
            $Result[$CurrentSection] = ProcessSectionContent -SectionLines $CurrentSectionLines
        }
        
        Write-Debug "Parsing complete. Found sections: $($Result.Keys -join ', ')"
        return [PSCustomObject]$Result
    }
}

function Get-OllamaModelList {
    ollama list | ConvertFrom-TextTable
}


function Get-OllamaModelInfo {
    param (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName)]
        [Alias("Name")]
        [string]$ModelName
    )
    
    begin {}

    process {
        ollama show $ModelName | ConvertFrom-OllamaModelInfo
    }

    end {}
}

