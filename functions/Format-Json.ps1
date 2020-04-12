# Original code obtained from https://github.com/PowerShell/PowerShell/issues/2736

# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
function Format-Json {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $InputObject
    )
    Begin {
        $Buffer = New-Object 'System.Collections.Generic.List[string]'
    }

    Process {
        $Buffer.Add($InputObject)
    }

    End {
        $json = [string]::Join("`n", $Buffer.ToArray())

        [int]$indent = 0;
        $result = ($json -Split '\n' |
            % {
                if ($_ -match '^\s*[\}\]]') {
                    # This line contains  ] or }, decrement the indentation level
                    if (--$indent -lt 0) {
                        #fail safe
                        $indent = 0
                    }
                }
                $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
                if ($_ -match '[\[\{](?!(.*[\{\[\"]))') {
                    # This line contains [ or {, increment the indentation level
                    $indent++
                }
                $line
            }) -Join "`n"

        # Unescape Html characters (<>&')
        $result.Replace('\u0027', "'").Replace('\u003c', "<").Replace('\u003e', ">").Replace('\u0026', "&")
    }
}
