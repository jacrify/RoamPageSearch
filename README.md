# RoamPageSearch
Alfred workflow for searching roam

Searches all roam pages using roam alpha api.

Currently supports:
1) Go to daily page by hotkey/keyword
2) Search and jump to page by filter
3) Go to named page by hotkey/keyword

Requires a roam tab to be open pointing to your database before it will work (script will open one on first run if not already open).

Has three environment variables: DBName: the name of your roam db. It's in the url of your roam pages: https://roamresearch.com/#/app/YOURDBNAME . This MUST be set before running. cacheTimeInSeconds: after running once, all page names will be cached for this number of seconds. Makes workflow slightly faster, but when you add pages they may not be there immediately. preferredBrowser: must be Chrome or Safari

When run, the workflow will query roam dynamically- type characters of page names to filter.  Once a page is selected, one of two things will happen: 1) If your preferred browser has a roam tab open and active, that tab will go to that page 2) If you do not have an active roam tab open, the first roam tab you have open will be navigated to that page.

 

Note that for this workflow to work, you need to enable AppleScript->Javascript in your browser of choice. 

To enable AppleScript->javascript in Chrome:

View>Developer>Allow Javascript from Apple Events

To enable AppleScript->javascript in Safari:

Safari Preference>Advanced>Show Developer Menu in menu bar Then Develop>Allow Javascript from Apple Events


Note this repo uses [osagitfilter](https://github.com/doekman/osagitfilter/) to manage the Applescript. Instructions available [here](https://forum.latenightsw.com/t/a-third-way-of-putting-applescript-into-git/1932).
