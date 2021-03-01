#Redmine inline edit issues

This is a redmine plugin that allows you to edit fields of multiple issues in one view.

##Installation

* To install this plugin just clone it in your redmine's plugins folder
* Run `rake redmine:plugins:migrate RAILS_ENV=production` in your redmine folder
* Restart your webserver

##Usage

###How to get to the Inline Edit screen
* Select a Project
* Click on the "Issues" tab.
* Check 2 or more issues (or click on the check at the top to select all).
* Right Click
* In the context menu, click on "Edit Inline"

###Editing fields
* The issues should appear as a form.  
* The issues that can be edited appear as the appropriate form field (text, select, checkbox, etc.)
* Fields that have been edited but not yet submitted will show as red.
* Hover over an edited field to see the original value.
* Reset all fields back to the original value by clicking on "Reset".
* "Cancel" returns to the previous screen without saving any changes

### Group Totals
* If "Estimated time" and "Spent time" fields have been selected for view, 
   the field values will be summed up and the total displayed at the bottom.
* If you have grouped the results (Under "Options"), 
   the estimated time and spent time totals will appear below each group.
   The grand total will appear at the bottom.
* As you edit the estimated time field, the group totals and grand totals will automatically update.
   NOTE: Spent time is not an editable field on this screen.


