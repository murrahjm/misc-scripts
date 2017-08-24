<#
add a custom action to the right-click sendTo menu.  allows for right-clicking on a powershell script, then sendTo...SSL signing to add a signature
    start, run, shell:SendTo
    add new item
    path:  C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -file C:\scripts\SSLSigning.ps1
#>
Function Add-SSLSignature{
    [cmdletbinding()]
    Param(
        [parameter(ValuefromPipeline=$True)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern({\.ps1$|\.psm1$|\.psd1$|\.ps1xml$})]
        [string[]]$FilePaths
    )
    BEGIN{
        Write-Verbose "Beginning SSLSign-Cert script"
        $timestampServer = "http://timestamp.comodoca.com/authenticode"
        $cert = (gci cert:\CurrentUser\My\ -CodeSigningCert)
    }
    PROCESS{
        Foreach($file in $FilePaths){
            Write-Verbose "Processing $file"
            rename-item $file "$file.old"
            get-content "$file.old" | set-content -Encoding utf8 "$file"
            remove-item "$file.old"
            Set-AuthenticodeSignature -FilePath $File -Certificate $cert -TimestampServer $timestampServer
        }
    }
    END{
        Write-Verbose "script complete"
    }
}
#host output and sleep so you can verify it worked and see any output
$args | add-sslSignature -Verbose
start-sleep 10