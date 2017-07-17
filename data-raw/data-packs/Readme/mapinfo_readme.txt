# Technical notes for MapInfo users
To open the 2016 DataPacks boundary files you need to use MapInfo version 7.8 or above.

When creating .tab files in MapInfo for SA1, SA2, SA3, SA4, STE or SLA, the 'region ID' in the CSV file has to be changed from 'integer' or 'small integer' to 'character', before merging with the corresponding boundary file.

This is not necessary with other geographies. The '.tab' files for other geographies can be opened and merged with the data file in the usual way.

To do this:
(In this example we are using MapInfo Professional 10.5 and the SA4 geography for South Australia)
1. Open MapInfo. 
2. Cancel *Quick Start*.
3. Select *File*.
4. Select *Open*.
5. When the *Open* tile appears:
    * In the field *Files of type* select *Comma delimited CSV*.
    * Select your CSV file.
    * Tick the *Create copy in MapInfo format for read/write* check box.
    * Press the *Open* button. The *Comma Delimited CSV Information* dialog box appears.
6. Tick the *Use First Line for Column Titles* box. Leave other settings as is. Then press the *OK* button.
7. The file will open. Select, *Table* -> *Maintenance* -> *Table Structure*.
8. Change *Small Integer* or *Integer* to *Character* for the region_id field.
9. The change to *Character* will bring up the *Width* dialog box.
10. The *width* is the number of characters in the geography code. In this case the geography is SA4. SA4s have three digit codes so enter 3.
11. Press OK.

*Note: Some geographies will have codes of more than three numerals and so will have commas. When counting the number of characters for the 'width' field, exclude the commas from the count.*

12. A box will appear saying: *One or more fields have been shortened or removed. The resulting loss of data cannot be undone.*
13. Press OK button and you have finished.

The data file can now be merged with the corresponding boundary file.