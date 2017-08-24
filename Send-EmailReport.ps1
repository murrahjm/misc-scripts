function Send-EmailReport{
<#
.Synopsis
    Sends formatted email of object output
.DESCRIPTION
    This script takes an input object or array of objects, organizes them into an HTML table, and sends a formatted HTML email to the specified recipients.
    Input object can be passed through the pipeline or specified by parameter.
    HTML table format includes a column for each property in the object.  Any formatting of properties or input data must be done before calling this function.
.PARAMETER To
    Specify the email address(es) to send the report to.
.PARAMETER Subject
    Specify the email subject.  If the header parameter is not specified the subject field is also used in the header of the email.
.PARAMETER Body
    Specify the object or array of objects to be included in the body of the email.  This object or objects are expanded into a table format and wrapped in HTML.
    If a property of an object is itself an object with properties or an array of objects, the script includes them in the standard powershell notation.  The script will not attempt to expand any of these properties
.PARAMETER SMTPServer
    The SMTP server to use for sending the email.  The default value should be sufficient for most cases.
.PARAMETER From
    The email address to use in the from field of the email.  The default value of PSReporting@domain.com should be sufficient for most cases, but this can be changed as needed.  There is no validation by the SMTP server, this doesn't need to be a valid email address
.PARAMETER Header
    Any text to be included at the top of the email, before the table of data is presented.  The default value of this is the email subject and current date/time.  This is presented in a larger font as an HTML header field.
.PARAMETER H2
	Any text to be included at the top of the email, before the table of data is presented but below the Header.  This is presented in a slightly smaller font than the Header field.
.PARAMETER H3
	Any text to be included at the top of the email, before the table of data but below the Header or H2 fields.  This is presented in the same font as the table data.
.PARAMETER AsAttachment
	This switch parameter causes the body data to be included as a csv attachment, rather than an HTML table in the email.
.EXAMPLE
    Get-ADUser -filter * | Send-EmailReport -To myboss@domain.com -subject "User List"
    This example gets all users in AD and sends the list in an email
#>

    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="Low")]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String[]]$To,

		[String[]]$CC,

        [Parameter(Mandatory=$True)]
        [String]$Subject,

        [Parameter(Mandatory=$True,
                   ValueFromPipeline=$True)]
        [Object[]]$Body,

		[Parameter(Mandatory=$True)]
        [String]$SMTPServer,

		[Parameter(Mandatory=$True)]
        [String]$From,

        [String]$Header,

		[String]$H2,

		[String]$H3,

		[Switch]$AsAttachment
    )

    Begin{
        $head = @'
<style>
html, body {
	height: 100%;
}
body, p, h1, h2, h3, li, td {
	font-family: 'Segoe UI', Verdana, Arial;
}
body {
	color: #000000; 
	margin:0; padding:0;
	font-size : .8em;	
	width:100%;
}
img {
	-ms-interpolation-mode:bicubic;
}
h1 {
	font-weight : bold;
	font-size : 1.3em;
	margin-top:.7em;
	margin-bottom: 1em;
	border-bottom: 1px silver solid;
	padding-bottom: 8px;
	padding-top:0px;
	color: #1A72B9;
}
h2 {
	font-weight : bold;
	font-size : 1.05em;
	margin-bottom: 0.25em;
	color: #1A72B9;
}
h3 {
	font-weight : bold;
	font-size : 1em;
	margin-bottom: 0.25em;
	color: #125095;
}
p {
	margin:0px 0em 1em 0em;
	line-height:1.5em;
}
li {
	margin-bottom: 4pt;
}
a:active, a:link, a:visited {
	text-decoration:underline;
}
a:hover		{
	text-decoration:none;
}
table {
	font-size: 1em; 
	margin-top: 1em 0 1em 0;		
	border-collapse:collapse;
	width:90%;
}
tr {
	vertical-align: top;	
}
th {
  background-color: #EDF6FF; 
  vertical-align: bottom;  
  color:#215A8F;
  padding:5px;
  border-bottom:1px solid #90ADBC;
}
td {
	vertical-align: top; 
	margin-top: .25em;	
	padding:10px;
	border-bottom:1px solid #90ADBC;
}
td, th {
	text-align: left; 
	padding-left:1em;  
	border-right:2px solid white;
}
small {
	font-size: .85em;
}
tt {
	font-family: monospace;
	font-size:1.1em;
}
pre {
	font-family: Consolas, Monaco, 'Bitstream Vera Sans Mono', 'Courier New', Courier, monospace;
	font-size: 1.02em;
	background-color:#F7F7F7;
	padding:1px 5px;
	/* Wrap content in pre tags if too long */
	overflow-x: auto; /* Use horizontal scroller if needed; for Firefox 2, not needed in Firefox 3 */
	white-space: pre-wrap; /* css-3 */
	white-space: -moz-pre-wrap !important; /* Mozilla, since 1999 */
	white-space: -pre-wrap; /* Opera 4-6 */
	white-space: -o-pre-wrap; /* Opera 7 */
	word-wrap: break-word; /* Internet Explorer 5.5+ */
}
 .syntax {
	margin-top: 0em;
	margin-left: 1em;
	margin-right: 1em;
	background-color: whitesmoke;
}
hr {
	color: silver;
	background-color: silver;
  height: 1px;
  border-bottom:1px solid #90ADBC;
}
</style>
'@
        If ($Header){
            $ReportHTML = "<h1>$Header</h1>"
        }else {
            $ReportHTML = "<h1>$Subject - $(Get-Date)</h1>"
        }
		If ($H2){
			$ReportHTML += "<h2>$H2</h2>"
		}
		If ($H3){
			$ReportHTML += "<h3>$H3</h3><br>"
		}
        Write-Verbose "Verifying connection to SMTP Server"
        Try{
            $socket = new-object Net.Sockets.TcpClient
            $socket.Connect($SMTPServer,25)
            if (! $socket.Connected){Throw}
        } Catch {
            Write-Error "Unable to connect to SMTP server $smtpserver.  Check your network connection" -ErrorAction Stop
        } Finally {
            $Socket.Close()
        }
     
    }
    Process{
        $output += $body
    }
    End{
		If ($AsAttachment){
			$attachment = "$($env:temp)\$Subject-$(get-date -UFormat "%m.%d.%y").csv"
			$output | Export-Csv -NoTypeInformation -Path $attachment -Force
		}else {
			$ReportHTML += $output | convertto-html -Head $head
			$ReportHTML += "<h2>Number of objects found:  $(($output | measure-object).count)</h2>"
		}
        if ($pscmdlet.ShouldProcess($To)){
			If ($attachment){
				If ($CC){
					Send-MailMessage -SmtpServer $SMTPServer -To $To -Cc $CC -Subject $Subject -Body "$ReportHTML" -BodyAsHtml -From $From -Attachments $attachment
				} else {
					Send-MailMessage -SmtpServer $SMTPServer -To $To -Subject $Subject -Body "$ReportHTML" -BodyAsHtml -From $From -Attachments $attachment
				}
				remove-item $attachment
            } else {
				If ($CC){
					Send-MailMessage -SmtpServer $SMTPServer -To $To -Cc $CC -Subject $Subject -Body "$ReportHTML" -BodyAsHtml -From $From
				} else {
					Send-MailMessage -SmtpServer $SMTPServer -To $To -Subject $Subject -Body "$ReportHTML" -BodyAsHtml -From $From
				}

			}
        }
    }
}
