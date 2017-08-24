Function ConvertTo-ReportObject {
<#
.Synopsis
   Modify pipeline object with report type data for database importing
.DESCRIPTION
   SQL Reporting functions in this module use the object type to determine which table to place the data in.  This type is in the format "report.<tablename>".
   For Example, to place data into the user table, the object type would be "report.user".  Note that this cmdlet assumes the "report." prefix, and only requires the Type field to be specified.

   Any properly formatted object or array of objects can be passed to this object.  Most common use is as a pipeline function.
.EXAMPLE
   Get-aduser -filter * | ConvertTo-ReportObject -Type User | Add-UserData

   This example takes ad user data from the get-aduser cmdlet, sets the type to "report.user", then passes it to the add-userdata cmdlet.  This is all done in the pipeline stream.
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
    Param(
        [Parameter(Mandatory=$True,
                   ValueFromPipeline=$True)]
        [object]$InputObject,

        [parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String]$Type
    )
    BEGIN{}
    PROCESS{
        foreach ($item in $InputObject){
            $props = @{}
            $item | gm | ?{($_.membertype -eq "Property") -or ($_.membertype -eq "NoteProperty")} | ForEach-Object {
                $props += @{$_.name = $($item.$($_.name))}
            }
            $output = New-Object -TypeName PSObject -Property $props
            $output.PSObject.Typenames.insert(0,"Report.$Type")
            write-output $output
        }
    }
    END{}
}
