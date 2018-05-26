# Original code obtained from https://github.com/PowerShell/PowerShell/issues/2736
# Modified @mkht in 2018-05-27

# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {

    if($PSVersionTable.PSVersion -ge '6.0.0'){
        # In PowerShell Core 6.0.0 or higher, Nothing to do it.
        $json
    }
    else{
        $indent = 0;
        ($json -Split '\n' |
        % {
            if ($_ -match '[\}\]]') {
            # This line contains  ] or }, decrement the indentation level
            $indent--
            }
            $line = (' ' * $indent * 4) + $_.TrimStart().Replace(':  ', ': ')
            if ($_ -match '[\{\[]') {
            # This line contains [ or {, increment the indentation level
            $indent++
            }
            $line
        }) -Join "`n"
    }
  }
