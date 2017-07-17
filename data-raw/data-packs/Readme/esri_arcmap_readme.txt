# Technical notes for ESRI ArcGIS 

## Converting region ID from numeric to text field
This is applicable to ArcGIS only.

When working with data files for SA1, SA2, SA3, SA4, STE or SLA, the **'region ID'** in the CSV file has to be changed from a numeric to a text type field, before any merger with the corresponding boundary file can occur. *Note that this is not necessary with other geographies. The '.tab' files for other geographies can be opened and merged with the data file in the usual way.*

To do this: (In this example we are using ArcMap 10.3.1)
1. Open *ArcGIS* -> *ArcMap*.
2. Cancel *ArcMap Getting started*.
3. Select *Windows* -> *Catalog*
4. In the *Catalog* window, right click on *Folder Connections* -> *Connect Folder*
5. Navigate to the folder location of the data file(s) to connect to folder for access in ArcMap.
6. Select the data file(s) you would like to convert the region ID field of.
7. Drag and drop the data file into your workspace (middle panel where maps are displayed).
8. Your data file should appear within the *Layers* level in your *Table of Contents* window.
9. Right click on csv file in the Table of contents window, select *Data* -> *Export*.
10. Click on the *browse* folder icon.
11. Navigate to your *Folder Connections* and select a folder to create a new Geodatabase, to store exported csv files (if you do not have one already).
a. To do this, select the highlighted icon to create a database. 
b. Give a new name to your database (for example *Validation_shape.gdb*).
12. Double click on your new geodatabase created.
13. Name your exported file (for example ***T01_AUST_STE*** – note name has a 13 character limit). 
14. Select *Save*.
15. The following dialog box should appear – select *OK* and note the output destination database and file name.
16. After the file is exported, a dialog box will appear with *Do you want to add the new table to the current map*. Select *Yes*.
17. In *Table of Contents* panel, open your new file within the database you created
 (for example ***T01_AUST_STE***).
18. Right click on file and select *Open*.
19. In the table that opens, select the drop down menu and *Add Field*.
20. Assign a name to new field (e.g. *region_id_txt*), select type as *Text*, then select *OK*.
21. In the table, scroll to the last column to locate new field. 
22. Right click on *region_id_txt*, then select *field calculator*.
23. Double click on *region_id* so that your new text field is equal to the contents of *region_id*
24. Select *OK*
You can now merge the boundary file (for example *state_code* from the *STE* boundary) with the appropriate data file (for instance *T01_AUST_STE*) using the new text field *region_id_txt*.