This module originally came from this e-book:  https://www.gitbook.com/book/devops-collective-inc/ditch-excel-making-historical-trend-reports-in-po/details

Added the following cmdlets for more functionality:

* update-reportdata - allows updating an existing record based on specified key value
* add-reportdata - decision cmdlet that will send data to either update-reportdata or add-reportdata depending on whether the record exists or not
* remove-reportdata - removes existing database records based on specified key value
* convertto-reportobject - pipeline cmdlet to add a specified object type to an object before sending to one of the *-reportdata cmdlets