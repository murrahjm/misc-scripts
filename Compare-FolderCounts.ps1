Function Compare-FolderCounts {
    <#
    .Synopsis
        Compares File counts between two folder paths
    .DESCRIPTION
        This cmdlet will count the files in two provided folders recursively and return a boolean comparison result.  If the -details switch is provided it will return the total counts of both folders as well as the paths.
    .EXAMPLE
        Compare-FolderCounts -sourcepath c:\temp -destinationpath c:\copytemp
        This will count the files in both folders and return a boolean TRUE or FALSE depending on the comparison of the two
    .EXAMPLE
        Compare-FolderCounts -sourcepath c:\folder1 -DestinationPath c:\folder2 -details
        This will count the files in both folders and output an object with the paths and counts of each folder, as well as the boolean TRUE FALSE comparison value.
    #>
        Param(
            [Parameter(Mandatory=$True)]
            [ValidateScript({Test-Path $_})]
            $SourcePath,
            
            [Parameter(Mandatory=$True)]
            [ValidateScript({Test-Path $_})]
            $DestinationPath,
    
            [Switch]$Details
        )
        $SourceCount = Get-FileCount $SourcePath
        $DestCount = Get-FileCount $DestinationPath
        If ($Details){
            New-Object -TypeName PSObject -Property @{
                'SourcePath' = $SourcePath
                'SourceCount'= $SourceCount
                'DestPath'   = $DestinationPath
                'DestCount'  = $DestCount
                'Match'      = $($SourceCount -eq $DestCount)
            }
        } else {
            [bool]$($SourceCount -eq $DestCount)
        }
    }
    Function Get-FileCount {
        Param($Path)
        Try{
            if ($Path -and (Test-Path $Path)) {
                $FolderCount = ([System.IO.Directory]::GetFiles($Path,"*","AllDirectories") |
                Where-Object{$_ -notlike "*DFSRPrivate*"} |
                Where-Object{$_ -notlike "*DFSR_DIAGNOSTICS_TEST_FOLDER*"} |
                Measure-Object).Count
            }
        }
        Catch{
            [System.Exception]
            $FolderCount = 0
        } Finally {
            $FolderCount
        }
    }
    