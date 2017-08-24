Function Get-RobocopyOutput {
<#
.SYNOPSIS
    Tool to parse robocopy logfiles into powershell objects containing result data
.DESCRIPTION
    This cmdlet will read the contents of a robocopy logfile and return a powershell object for each robocopy log in the file that contains the source and destination paths as well as the details of the copy results.
    Additionally if the path provided to the cmdlet is a directory it will scan all subfolders for robocopy log files to process.
.PARAMETER Path
    A string value representing the path to the log file to be parsed or a directory containing multiple log files.
.PARAMETER Recurse
    A switch value indicating whether the script should search for log files recursively through the provided path.
.PARAMETER FileCount
    A switch value indicating whether file count data should be included in the robocopy output.  This is enabled by default.
.PARAMETER DirCount
    A switch value indicating whether directory count data should be included in the robocopy output.  This is disabled by default.
.PARAMETER BytesCount
    A switch value indicating whether file size data should be included in the robocopy output.  This is disabled by default.
.PARAMETER TimesCount
    A switch value indicating whether elapsed time data should be included in the robocopy output.  This is disabled by default.
.PARAMETER Flat
    A switch value indicating whether the output object should be a single entity with string properties, or whether certain properties should themselves be objects.  Flat output is more compatible with CSV or HTML output.
.EXAMPLE
    "C:\scripts\" | Get-RobocopyOutput -recurse
    This example will search for robocopy log files within the specified folder and all subfolders.  Any log files that are found will be parsed and the output will be presented.
.EXAMPLE
    Get-RobocopyOutput -Path C:\temp\robocopy.log
    This will process the single file specified and output the relevant file copy data.
.EXAMPLE
    Get-RobocopyOutput -Path c:\temp -Recurse -FileCount -Flat | export-csv -NoTypeInformation -Path c:\temp\RobocopyLogs.csv
    This will search the temp folder recursively for any robocopy logfiles, process the results and include only file count details.
    It will also format the output in a flat format rather than using child objects.  This flat structure is passed to export-csv and will create a correctly formatted csv file output.
#>

    Param(
        [Parameter(Mandatory=$True,
                    ValueFromPipeline=$True)]
        [ValidateScript({Test-Path $_})]
        [String[]]$Path,

        [Switch]$Recurse,

        [Switch]$FileCount=$True,

        [Switch]$DirCount,

        [Switch]$BytesCount,

        [Switch]$TimesCount,

        [Switch]$Flat
    )
    BEGIN{
    }
    PROCESS{
        Write-Verbose "Processing $path"    
        If ($(Get-item $Path).PSIsContainer){
            write-verbose "Parameter value is a folder, parsing items"
            $path = (get-childitem -File -Recurse:$Recurse $path).Fullname
        }
        Foreach ($item in $path){
            write-verbose "Parsing logfile $item"
            $output = ConvertFrom-RobocopyLog -content $(get-content $item)
            $output | ForEach-Object{
                Add-Member -InputObject $_ -type NoteProperty -name Logfile -Value $item
                If ($FileCount){
                    If ($Flat){
                        Add-Member -InputObject $_ -Type NoteProperty -name FileCountExtras -Value $_.FileCount.Extras
                        Add-Member -InputObject $_ -Type NoteProperty -name FileCountMismatch -Value $_.FileCount.Mismatch
                        Add-Member -InputObject $_ -Type NoteProperty -name FileCountTotal -Value $_.FileCount.Total
                        Add-Member -InputObject $_ -Type NoteProperty -name FileCountCopied -Value $_.FileCount.Copied
                        Add-Member -InputObject $_ -Type NoteProperty -name FileCountFailed -Value $_.FileCount.Failed
                        Add-Member -InputObject $_ -Type NoteProperty -name FileCountSkipped -Value $_.FileCount.Skipped
                        $_.PSObject.Properties.Remove('FileCount')
                    }
                } else {
                    Write-Verbose "Removing FileCount property"
                    $_.PSObject.Properties.Remove('FileCount')
                }
                If ($DirCount){
                    If ($Flat){
                        Add-Member -InputObject $_ -Type NoteProperty -name DirCountExtras -Value $_.DirCount.Extras
                        Add-Member -InputObject $_ -Type NoteProperty -name DirCountMismatch -Value $_.DirCount.Mismatch
                        Add-Member -InputObject $_ -Type NoteProperty -name DirCountTotal -Value $_.DirCount.Total
                        Add-Member -InputObject $_ -Type NoteProperty -name DirCountCopied -Value $_.DirCount.Copied
                        Add-Member -InputObject $_ -Type NoteProperty -name DirCountFailed -Value $_.DirCount.Failed
                        Add-Member -InputObject $_ -Type NoteProperty -name DirCountSkipped -Value $_.DirCount.Skipped
                        $_.PSObject.Properties.Remove('DirCount')
                    }
                } else {
                    Write-Verbose "Removing DirCount property"
                    $_.PSObject.Properties.Remove('DirCount')
                }
                If ($BytesCount){
                    If ($Flat){
                        Add-Member -InputObject $_ -Type NoteProperty -name BytesCountExtras -Value $_.BytesCount.Extras
                        Add-Member -InputObject $_ -Type NoteProperty -name BytesCountMismatch -Value $_.BytesCount.Mismatch
                        Add-Member -InputObject $_ -Type NoteProperty -name BytesCountTotal -Value $_.BytesCount.Total
                        Add-Member -InputObject $_ -Type NoteProperty -name BytesCountCopied -Value $_.BytesCount.Copied
                        Add-Member -InputObject $_ -Type NoteProperty -name BytesCountFailed -Value $_.BytesCount.Failed
                        Add-Member -InputObject $_ -Type NoteProperty -name BytesCountSkipped -Value $_.BytesCount.Skipped
                        $_.PSObject.Properties.Remove('BytesCount')
                    }
                } else {
                    Write-Verbose "Removing BytesCount Property"
                    $_.PSObject.Properties.Remove('BytesCount')
                }
                If ($TimesCount){
                    If ($Flat){
                        Add-Member -InputObject $_ -Type NoteProperty -name TimesCountExtras -Value $_.TimesCount.Extras
                        Add-Member -InputObject $_ -Type NoteProperty -name TimesCountTotal -Value $_.TimesCount.Total
                        Add-Member -InputObject $_ -Type NoteProperty -name TimesCountCopied -Value $_.TimesCount.Copied
                        Add-Member -InputObject $_ -Type NoteProperty -name TimesCountFailed -Value $_.TimesCount.Failed
                        $_.PSObject.Properties.Remove('TimesCount')
                    }
                } else {
                    Write-Verbose "Removing TimesCount Property"
                    $_.PSObject.Properties.Remove('TimesCount')
                }
                write-output $_
            }
        }
    }
    END{}
}
Function ConvertFrom-RobocopyLog {
    Param([string[]]$content)
    If ($content -match "Robust File Copy for Windows"){
        write-verbose "Input is a robocopy log file, processing"
        $content | ForEach-Object{
            Switch -wildcard ($_){
                "   ROBOCOPY     ::     Robust File Copy for Windows                              " {$jobdata = new-object -TypeName psobject}
                "  Started : *"{$jobdata | Add-Member -Type NoteProperty -name 'Started' -Value $([datetime]::ParseExact($($_.trimstart("  Started : ")),"ddd MMM dd H:m:s yyyy",$Null))}
                "   Source : *"{$jobdata | Add-Member -Type NoteProperty -name 'Source' -Value $_.TrimStart("   Source : ")}
                "     Dest : *"{$jobdata | Add-Member -Type NoteProperty -name 'Destination' -Value $_.TrimStart("     Dest : ")}
                "    Files : *"{$jobdata | Add-Member -Type NoteProperty -name 'Files' -Value $_.TrimStart("    Files : ")}
                "  Options : *"{$jobdata | Add-Member -Type NoteProperty -name 'Options' -Value $_.TrimStart("  Options : ")}
                "               Total    Copied   Skipped  Mismatch    FAILED    Extras" {$jobdata | Add-Member -Type NoteProperty -name 'Status' -Value "success"}
                "    Dirs : *"{$jobdata | Add-Member -Type NoteProperty -name 'DirCount' -Value $(Split-CountResults -string $_.TrimStart("    Dirs :"))}
                "   Files : *"{$jobdata | Add-Member -Type NoteProperty -name 'FileCount' -Value $(Split-CountResults -string $_.TrimStart("   Files :"))}
                "   Bytes : *"{$jobdata | Add-Member -Type NoteProperty -name 'BytesCount' -Value $(Split-CountResults -string $_.TrimStart("   Bytes :"))}
                "   Times : *"{$jobdata | Add-Member -Type NoteProperty -name 'TimesCount' -Value $(Split-TimeResults -string $_.TrimStart("   Times :"))}
                "   Ended : *"{$jobdata | Add-Member -Type NoteProperty -name 'Ended' -Value $([datetime]::ParseExact($($_.trimstart("   Ended : ")),"ddd MMM dd H:m:s yyyy",$Null)); $jobdata}
                "*ERROR 2 (0x00000002) Accessing Source Directory*" {$jobdata | Add-Member -Type NoteProperty -name 'Status' -Value "Failed"; $jobdata}
            }
        }
    } else {
        Write-Verbose "Input is not a robocopy logfile"
    }

}
Function Split-CountResults {
    Param($string)
    $separator = " "
    $option = [System.StringSplitOptions]::RemoveEmptyEntries
    #for bytecount, remove space before size designator
    $string = $string.replace(" b","b").replace(" k","k").replace(" m","m").replace(" g","g")
    $array = $string.Split($separator,$option)
    New-Object -TypeName psobject -Property @{
        'Total'    = $array[0]
        'Copied'   = $array[1]
        'Skipped'  = $array[2]
        'Mismatch' = $array[3]
        'Failed'   = $array[4]
        'Extras'   = $array[5]
    }
}
Function Split-TimeResults {
    Param($string)
    $separator = " "
    $option = [System.StringSplitOptions]::RemoveEmptyEntries
    $array = $string.Split($separator,$option)
    New-Object -TypeName psobject -Property @{
        'Total'    = New-TimeSpan -hours $array[0].split(':')[0] -Minutes $array[0].split(':')[1] -Seconds $array[0].split(':')[2]
        'Copied'   = New-TimeSpan -hours $array[1].split(':')[0] -Minutes $array[1].split(':')[1] -Seconds $array[1].split(':')[2]
        'Failed'   = New-TimeSpan -hours $array[2].split(':')[0] -Minutes $array[2].split(':')[1] -Seconds $array[2].split(':')[2]
        'Extras'   = New-TimeSpan -hours $array[3].split(':')[0] -Minutes $array[3].split(':')[1] -Seconds $array[3].split(':')[2]
    }

}
