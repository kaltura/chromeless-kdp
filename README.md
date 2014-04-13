chromeless-kdp
==============

light&amp;chromeless kdp OSMF 2.0 player that will work with the new HTML5 (2.0+) player

Project-setup
=============
Main required projects to build chromeless player are KDP3, lightKdp3Lib, as3FlexClient, and all projects under "vendors". All other plugins can be imported by demand.

Default Flex SDK is: 4.5.1A

After importing the desired projects to your Flash Builder workspace go to: Window --> Preferences --> General --> Workspace --> Linked Resource:

1. Change ${Documents} value to your git repository root folder

2. Add ${linkReport}, it should point to [workspace]/KDP3/bin-debug/linkReport.xml


