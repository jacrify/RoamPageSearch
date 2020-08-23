#@osa-lang:AppleScript
#@osa-lang:AppleScript
#Roam Reuse 2.0

#Copyright 2020, John Cranney
#Copying and distribution of this file, with or without modification, are permitted in any medium without royalty, provided the copyright notice and this notice are preserved. This file is offered as-is, without any warranty.


# Finds a Roam tab in the selected browser, pointing to the selected database.
# Checks first to see if current tab in selected broswer is pointing at roam
# If not iterates through all windows and all tabs
# If no tab is found, asks user to open one.
#
# Once window is found, there are three modes, signified by the first arg passed:
# getAllPages : operates in query mode: injects javascript to call roam API and get list of all pages, with page ids. Designed to be used with Alfred filter
# goToPageByName : goes to a names page. Useful for pages you jump to often.
# gotoDaily: go to today's daily page
# goToPageByID: jump to page by id

# If no argument was passed, then
# If argument was passed, then assumes argument is a pageid, and sets roam tab to go to that page.
#TODO if url of page is already there don't do anything

global browsername
global keydelay
#time of last run.
property lastRunTime : 0
#cached response
property response : ""

###################################################################
# Utility functions
###################################################################
to getTimeInHoursAndMinutes()

	-- Get the "hour"
	set timeStr to time string of (current date)
	set Pos to offset of ":" in timeStr
	set theHour to characters 1 thru (Pos - 1) of timeStr as string
	set timeStr to characters (Pos + 1) through end of timeStr as string

	-- Get the "minute"
	set Pos to offset of ":" in timeStr
	set theMin to characters 1 thru (Pos - 1) of timeStr as string
	set timeStr to characters (Pos + 1) through end of timeStr as string

	--Get "AM or PM"
	set Pos to offset of " " in timeStr
	set theSfx to characters (Pos + 1) through end of timeStr as string

	return (theHour & ":" & theMin & " " & theSfx) as string

end getTimeInHoursAndMinutes


to date_format(old_date)
	set {year:y, month:m, day:d} to (old_date)

	tell (y * 10000 + m * 100 + d) as string to text 5 thru 6 & "-" & text 7 thru 8 & "-" & text 1 thru 4
end date_format

on convertListToString(theList, theDelimiter)
	set AppleScript's text item delimiters to theDelimiter
	set theString to theList as string
	set AppleScript's text item delimiters to ""
	return theString
end convertListToString

###################################################################
# Browser specific handling
###################################################################
on goToSafariPage(w, u)
	#Set URL mode.
	#activate chrome window, set url
	log "Setting url of safafi"
	tell application "Safari"
		activate
		set index of w to 1
		if URL of document 1 is not u then
			set URL of document 1 to u
		end if
	end tell
	#this delay seems to be needed to remove timing voodo
	delay 0.1
	tell application "System Events"
		tell application process "Safari"
			tell window 1
				perform action "AXRaise"
			end tell
		end tell
	end tell
end goToSafariPage

on injectSafariJavascript(w, j)
	tell application "Safari"
		set index of w to 1
		set pageID to (do JavaScript j in document 1)

	end tell
end injectSafariJavascript

on injectChromeJavascript(w, j)
	# Inject Javascript mode
	log "Injecting javascript into chrome"
	using terms from application "Google Chrome"
		tell application browsername
			set index of w to 1

			#So this is nuts.
			#Google chrome lets you execute javascript through applescript
			#But this javascript cannot access any page objects eg roamAlphaAPI
			#We can cheat by running our javascript through setting the window location to javascript:blah
			#and then pulling data out through session object
			#But setting url of active tab pulls chrome to front
			#So instead, we run javascript to set the location of the current tab to be a javascript that queries roamAlphaAPI and dumps into session
			#And amazingly that works
			#set js to "window.location.href = \"javascript:sessionStorage.setItem('roamapihackery', " & j & ")\""
			set js to "window.location.href = \"javascript:" & j & ";sessionStorage.setItem('roamapihackery', jsreturn)\""
			execute front window's active tab javascript js
			set response to {execute front window's active tab javascript "sessionStorage.getItem('roamapihackery')"}
		end tell
	end using terms from
end injectChromeJavascript

on goToChromePage(w, u)
	#Set URL mode.
	#activate chrome window, set url
	log "Setting url of chrome"
	using terms from application "Google Chrome"
		tell application browsername
			activate
			set index of w to 1
			if URL of active tab of w is not u then
				tell w to set URL of active tab to u
			end if
		end tell
	end using terms from

	#this delay seems to be needed to remove timing voodo
	delay 0.1
	tell application "System Events"
		tell application process browsername
			tell window 1
				perform action "AXRaise"
			end tell
		end tell
	end tell
end goToChromePage

on addToTopOfPage(headingtoadd, texttoadd, pastemode, addtodo)

	tell application "System Events"
		delay keydelay * 2
		#escape- remove focus if there already
		key code 53
		delay keydelay

		#command enter: focus on first block
		key code 36 using command down
		delay keydelay

		#left arrow- start of line in case there is already something here
		key code 123 using command down
		delay keydelay

		#enter- add new line
		key code 36
		delay keydelay

		#create heading, with indented block underneath
		set outstring to headingtoadd & return & linefeed
		keystroke outstring
		delay keydelay
		#tab
		key code 48
		#if (pastemode) then
		#	set the clipboard to outstring & (the clipboard)
		#else
		#	set the clipboard to outstring
		#end if
		if (addtodo) then
			delay keydelay
			key code 36 using command down
		end if


		if ((system attribute "addtimestamp") is "true") then
			delay keydelay
			set ts to my getTimeInHoursAndMinutes()
			keystroke ts & ": "
		end if

		if (pastemode) then
			delay keydelay
			tell application "System Events" to keystroke "v" using command down
		end if
		#end if
		#delay keydelay
		#down arrow to focus on start of entry
		#key code 125

		#keystroke texttoadd
	end tell

end addToTopOfPage

#when landing on a page, put the focus on a new empty block at bottom
on focusBottomOfPage(texttoadd, pastemode, addtodo)

	tell application "System Events"
		delay keydelay * 2
		#escape- remove focus if there already
		key code 53
		delay keydelay
		#command enter: focus on title
		key code 36 using command down
		delay keydelay
		#select all twice- selects all text, then right arrow takes us to end
		keystroke "a" using command down
		delay keydelay
		keystroke "a" using command down
		delay keydelay
		#down arrow
		key code 124
		delay keydelay
		#enter
		key code 36
		if (addtodo) then
			delay keydelay
			key code 36 using command down
		end if
		if ((system attribute "addtimestamp") is "true") then
			delay keydelay
			set ts to my getTimeInHoursAndMinutes()
			keystroke ts & ": "
		end if
		if (pastemode) then
			delay keydelay
			tell application "System Events" to keystroke "v" using command down
		end if

		#delay 0.1
		#keystroke texttoadd
	end tell

end focusBottomOfPage



###################################################################
# Main entrypoint
###################################################################


on run argv
	###################################################################
	# Setup and parse parms
	###################################################################


	set dbname to (system attribute "DBName")
	set configPageName to (system attribute "configPageName")
	set keydelay to (system attribute "keydelay") as number
	set mode to (system attribute "mode")

	set paste to (system attribute "paste")
	if paste is "true" then
		set pastemode to true
	else
		set pastemode to false
	end if

	set todo to (system attribute "todo")
	if todo is "true" then
		set addtodo to true
	else
		set addtodo to false
	end if

	log "Mode: " & mode
	log "PasteMode: " & pastemode
	log "AddToDo:" & addtodo


	set start to GetTick's Now()

	if (dbname is "") then
		display dialog "Please set DBName in workflow environment variables"
		return
	end if


	set preferredBrowser to (system attribute "preferredBrowser")
	if (preferredBrowser is "" or (preferredBrowser is not "Safari" and preferredBrowser is not "Chrome" and preferredBrowser is not "Brave" and preferredBrowser is not "Vivaldi")) then
		display dialog "Please set preferredBrowser in workflow environment variables to either Safari, Chrome, Vivaldi, or Brave"
		return
	end if

	if preferredBrowser is "Chrome" then
		set browsername to "Google Chrome"
	end if

	if preferredBrowser is "Brave" then
		#treat Brave as chrome
		set preferredBrowser to "Chrome"
		set browsername to "Brave Browser"
	end if


	if preferredBrowser is "Vivaldi" then
		#treat Brave as chrome
		set preferredBrowser to "Chrome"
		set browsername to "Vivaldi"
	end if

	###################################################################
	# Set up for different modes
	###################################################################

	#Having braces [] or tags # in search titles throws out Alfreds autocomplete, so we remove them
	#below using this snippet of javascript
	set bracestrip to ".split('[').join('').split(']').join('').split('#').join('')"

	#this clojure rule finds any ancestor of block ?block
	set ancestorrule to "'[ [ (ancestor ?block ?ancestor) [?ancestor :block/children ?block] ] [ (ancestor ?block ?ancestor) [?parent :block/children ?block ] (ancestor ?parent ?ancestor) ] ] ]'"

	if mode is "goToPageByID" then
		#target page is a page id
		set targetPage to item 1 of argv

	else if mode is "goToPageByName" then

		#targetPageName is a page name
		set targetPageName to item 1 of argv

		#this javascript searchs for a page matching a string, and returns the block uid. It's really horrid and should be destroyed and then burned.
		#todo rewrite with pull parameter
		set searchjavascript to "jsreturn=window.roamAlphaAPI.q('[:find ?e :in $ ?a :where [?e :node/title ?a]]','" & targetPageName & "').length==0 ? '':window.roamAlphaAPI.pull('[*]',window.roamAlphaAPI.q('[:find ?e :in $ ?a :where [?e :node/title ?a]]','" & targetPageName & "')[0][0])[':block/uid']"
	else if mode is "getAllPages" then
		#get all page titles
		set targetPage to ""
		#Javascript does the following:
		#Get dbids of all pages in roam database : window.roamAlphaAPI.q('[:find ?e :where [?e :node/title]]')
		#Iterate through each id and pull page details: window.roamAlphaAPI.pull('[*]', n[0])
		#Build json from title, pageid. We hack the full url we want to navigate to into the url. It's crappy but best do it here rather than in the applescript that sends the browser to the url
		#Square braces seem to throw Alfred filtering out, so we strip them out.
		#todo rewrite with pull parameter

		set getallpagesjavascript to "jsreturn =JSON.stringify({items:window.roamAlphaAPI.q('[:find ?e :where [?e :node/title]]').map(n=>{let o=window.roamAlphaAPI.pull('[*]', n[0]);return {title:o[':node/title']" & bracestrip & ",uid:o[':block/uid'],arg:o[':block/uid']}})})"


	else if mode is "getConfigPageData" then


		set targetPage to ""
		#TODO error handle this not being there
		#This is the content of the block on config page to pull into menu
		set targetblock to item 1 of argv

		#Javascript does the following:
		#find page called RoamSearchConfig
		#find block on page with contents = targetblock
		#return contents of all children of that block
		#note the random bullshit to string [] out of the string title so alfred will filter it.
		#note also that we add an indicator to show you can drill down through children if present
		#arg passed to alfred is the full string tag
		set getconfigpagejavascript to "jsreturn =JSON.stringify({items:window.roamAlphaAPI .q('[:find (pull ?optionblock [[:block/string] [:block/children]]) :in $ ?configpagetitle ?menublockstring % :where [?configpage :node/title ?configpagetitle]  [?menublock :block/string ?menublockstring] (ancestor ?menublock ?configpage) [?menublock :block/children ?optionblock]  ]', '" & configPageName & "','" & targetblock & "', " & ancestorrule & " ).map(n=> {return {title: n[0].string" & bracestrip & " + (n[0].children?' (⌥ to see children)':''),arg:n[0].string}})})"
		log "Javscript to inject: " & getconfigpagejavascript


		#The following is not fully implemented yet and is not exposed to alfred. It works but dropping down through levels does not work
	else if mode is "getConfigByTag" then


		set targetPage to ""
		#TODO error handle this not being there
		#This is the content of the block on config page to pull into menu
		set targetblock to item 1 of argv

		#Javascript does the following:
		# find blocks tagged with passed arg
		# return contents of all children of that block to build a menu
		#arg passed to alfred is the full string tag
		set getconfigpagejavascript to "jsreturn =JSON.stringify({items:window.roamAlphaAPI .q('[:find (pull ?optionblock [[:block/string] [:block/children] [:block/refs]]) :in $ ?menutag  :where [?configpage :node/title ?menutag]  [?menublock :block/refs ?configpage] [?menublock :block/children ?optionblock] ]', '" & targetblock & "').filter(b=>b[0].refs).map(n=> {return {title: n[0].string" & bracestrip & " + (n[0].children?' (⌥ to see children)':''),arg:n[0].string}})})"
		log "Javscript to inject: " & getconfigpagejavascript

	else if mode is "getConfigPageNames" then

		set targetPage to ""
		#TODO error handle this not being there
		set targetblock to item 1 of argv

		#Javascript does the following:
		#find page called RoamSearchConfig
		#find block on page with contents = targetblock
		#return names of pages each child of targetblock references
		# only one reference is returned per child (the oldest). This means [[[[foo]][[bar]]]] should return [[foo]][[[bar]]

		#arg passed to alfred is the full string tag
		set getconfigpagejavascript to "jsreturn =JSON.stringify({items:window.roamAlphaAPI .q('[:find (pull ?optionblock [[:block/string] [:block/children] [:block/refs]]) :in $ ?configpagetitle ?menublockstring % :where [?configpage :node/title ?configpagetitle]  [?menublock :block/string ?menublockstring]  [?menublock :block/children ?optionblock] (ancestor ?menublock ?configpage) ]', '" & configPageName & "','" & targetblock & "', " & ancestorrule & ").filter(b=>b[0].refs).map(b=>b[0].refs.slice(-1)[0]).map(r=>window.roamAlphaAPI.pull('[:node/title]',r.id)).map(r=>{return {title:r[':node/title']" & bracestrip & ",arg:r[':node/title']}})})"
		log "Javscript to inject: " & getconfigpagejavascript



	else if mode is "gotoDaily" then

		#go straight to daily page

	else if mode is "quickEntryDaily" then

		#go to daily page, then do quick entry
		set targetTag to item 1 of argv
		log "TargetTag:" & targetTag
		set dailyDate to date_format(current date)

		if length of argv > 2 then
			#shift args to get remaining text
			set argv to rest of argv
			set argv to rest of argv

			set textToEnter to convertListToString(argv, space)

		else
			set textToEnter to ""
		end if


		#clojure query to get block id of block on daily page which links to tag. Uses ancestor rule to recursively pull blocks.
		set quickentryjavascript to "{let tempout=window.roamAlphaAPI.q('[:find (pull ?dailypageblock [:block/uid]) :in $ ?dailypagetitle ?tagtitle % :where [?dailypageblock :block/string ?tagtitle]  [?dailypage :block/uid ?dailypagetitle]  (ancestor ?dailypageblock ?dailypage) ]','" & dailyDate & "','" & targetTag & "'," & ancestorrule & ");if (tempout.length>0) {jsreturn=tempout[0][0].uid} else {jsreturn ='notfound'}}"

	else
		display dialog "Unknown mode selector passed"
		return
	end if


	#cache result if this is a query run
	if mode is "getAllPages" then
		if response is not "" then
			set cacheTimeInSeconds to (system attribute "cacheTimeInSeconds") as number
			#cache results for some time to make it faaaaast
			set timeSinceLastRun to start - lastRunTime
			set lastRunTime to start

			if (lastRunTime is not 0) and (timeSinceLastRun < cacheTimeInSeconds) then
				return response
			end if
		end if
	end if



	set windowIndex to 1
	#current tab being scanned
	set tabIndex to 0


	set searchString to "roamresearch.com/#/app/" & dbname

	#list of list of tab urls from all windows
	set allWindowsTabURLList to ""
	#list of list of tab titles from all windows
	set allWindowsTabTitlesList to ""
	#list of all windows, chrome first, then safari
	set allWindowsList to ""

	set windowIndex to 1
	set found to false

	#stop looping when we get back to where we started, to handle cast where no tabs found
	set tabIndex to 1
	set windowsSearched to 0

	set foundWindow to ""


	if preferredBrowser is "Chrome" then
		###################################################################
		# Find Chrome tab running roam
		###################################################################



		# Check if current chrome tab is a roam tab
		using terms from application "Google Chrome"
			tell application browsername
				set activeURL to URL of active tab of first window
				if ((activeURL as text) contains searchString) then
					set found to true
					set foundWindow to first window

				end if
			end tell
		end using terms from
		#if not search through all windows
		if found is not true then
			using terms from application "Google Chrome"
				tell application browsername
					set allWindowsList to windows
					set allWindowsTabURLList to URL of tabs of every window
					set allWindowsTabTitlesList to title of tabs of every window
				end tell
			end using terms from
			#iterate through all windows
			repeat while windowIndex ≤ length of allWindowsTabURLList and windowIndex > 0
				set thisWindowsTabsURLs to item windowIndex of allWindowsTabURLList
				set thisWindowsTabsTitles to item windowIndex of allWindowsTabTitlesList
				#iterate through all tabs in each window
				repeat while tabIndex ≤ length of thisWindowsTabsURLs and tabIndex > 0
					set TabURL to item tabIndex of thisWindowsTabsURLs
					if ((TabURL as text) contains searchString) then
						using terms from application "Google Chrome"
							tell application browsername

								set foundWindow to item windowIndex of allWindowsList
								#activate this tab
								tell foundWindow to set active tab index to tabIndex
							end tell
						end using terms from
						set found to true
						exit repeat
					end if
					set tabIndex to tabIndex + 1
				end repeat

				if found then exit repeat

				set tabIndex to 1
				set windowIndex to windowIndex + 1
				if windowIndex > length of allWindowsTabURLList then
					set windowIndex to 1
				end if

				set windowsSearched to windowsSearched + 1
				if windowsSearched > length of allWindowsList then
					exit repeat
				end if
			end repeat
		end if

		###################################################################
		# Execute according to mode in chrome
		###################################################################


		if found then
			if mode is "goToPageByName" then
				#find the page uid
				set pageID to injectChromeJavascript(foundWindow, searchjavascript)
				#TODO we should really check if this is not found
				set pageURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & pageID
				goToChromePage(foundWindow, pageURL)
				#end if

			else if mode is "gotoDaily" then
				set targetURL to "https://roamresearch.com/#/app/" & dbname
				goToChromePage(foundWindow, targetURL)

			else if mode is "goToPageByID" then
				set targetURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & targetPage
				goToChromePage(foundWindow, targetURL)

			else if mode is "quickEntryDaily" then
				set targetURL to "https://roamresearch.com/#/app/" & dbname

				set pageID to injectChromeJavascript(foundWindow, quickentryjavascript)

				if (pageID as string) is equal to "notfound" then
					#add tag to daily notes page
					goToChromePage(foundWindow, targetURL)
					addToTopOfPage(targetTag, textToEnter, pastemode, addtodo)
				else
					set pageURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & pageID
					goToChromePage(foundWindow, pageURL)
					focusBottomOfPage(textToEnter, pastemode, addtodo)
				end if

			else if mode is "getConfigPageData" or mode is "getConfigPageNames" then
				set resp to injectChromeJavascript(foundWindow, getconfigpagejavascript)

				if resp is "{\"items\":[]}" then
					display dialog "Menu configuration tag not found on RoamSearchConfig page. Read the docs :)"
				end if
				log "Config loaded from roam. Resp :" & resp
				return resp

			else if mode is "getAllPages" then
				return injectChromeJavascript(foundWindow, getallpagesjavascript)
			end if
		end if
		if not found then
			using terms from application "Google Chrome"
				tell application browsername
					open location "https://" & searchString
				end tell
			end using terms from
			display dialog "You must have a tab in your preferred browser (Chrome) open on your roam database. Opening one for you, once open please try again"
		end if
		return

	end if



	if preferredBrowser is "Safari" then
		###################################################################
		# Find Safari tab running roam
		###################################################################

		# Check if current chrome tab is a roam tab
		tell application "Safari"
			set activeURL to URL of front document
			if ((activeURL as text) contains searchString) then
				set found to true
				set foundWindow to first window
			end if
		end tell

		#if not search through all windows
		if found is not true then
			tell application "Safari"
				set allWindowsList to windows
				set allWindowsTabURLList to (URL of tabs of every window)
				set allWindowsTabTitlesList to (name of tabs of every window)
			end tell

			#iterate through all windows
			repeat while windowIndex ≤ length of allWindowsTabURLList and windowIndex > 0
				set thisWindowsTabsURLs to item windowIndex of allWindowsTabURLList
				set thisWindowsTabsTitles to item windowIndex of allWindowsTabTitlesList
				#iterate through all tabs in each window
				repeat while tabIndex ≤ length of thisWindowsTabsURLs and tabIndex > 0
					set TabURL to item tabIndex of thisWindowsTabsURLs
					if ((TabURL as text) contains searchString) then
						tell application "Safari"
							set foundWindow to item windowIndex of allWindowsList
							#activate this tab
							tell foundWindow to set current tab to tab tabIndex
						end tell
						set found to true
						exit repeat
					end if
					set tabIndex to tabIndex + 1
				end repeat

				if found then exit repeat

				set tabIndex to 1
				set windowIndex to windowIndex + 1
				if windowIndex > length of allWindowsTabURLList then
					set windowIndex to 1
				end if

				set windowsSearched to windowsSearched + 1
				if windowsSearched > length of allWindowsList then
					exit repeat
				end if
			end repeat
		end if



		if found then
			if mode is "goToPageByName" then

				#find the page uid
				set pageID to injectSafariJavascript(foundWindow, searchjavascript)
				#TODO we should really check if this is not found
				set pageURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & pageID
				goToSafariPage(foundWindow, pageURL)

			else if mode is "goToPageByID" then
				set targetURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & targetPage
				goToSafariPage(foundWindow, targetURL)


			else if mode is "gotoDaily" then
				set targetURL to "https://roamresearch.com/#/app/" & dbname
				goToSafariPage(foundWindow, targetURL)

			else if mode is "quickEntryDaily" then


				set targetURL to "https://roamresearch.com/#/app/" & dbname

				set pageID to injectSafariJavascript(foundWindow, quickentryjavascript)
				if (pageID as string) is equal to "notfound" then
					#display dialog "pageID"
					#add tag to daily notes page
					goToSafariPage(foundWindow, targetURL)
					addToTopOfPage(targetTag, textToEnter, pastemode, addtodo)
				else
					set pageURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & pageID
					goToSafariPage(foundWindow, pageURL)
					focusBottomOfPage(textToEnter, pastemode, addtodo)
				end if

			else if mode is "getConfigPageData" or mode is "getConfigPageNames" then
				set resp to injectSafariJavascript(foundWindow, getconfigpagejavascript)

				if resp is "{\"items\":[]}" then
					display dialog "Menu configuration tag not found on RoamSearchConfig page. Read the docs :)"
				end if
				return resp

			else if mode is "getAllPages" then
				# Inject Javascript mode
				log "Injecting javascript into safari"
				tell application "Safari"
					set index of foundWindow to 1
					set response to (do JavaScript getallpagesjavascript in document 1)
					return response
				end tell
			end if
		end if
		if not found then
			tell application "Safari"
				open location "https://" & searchString
			end tell
			display dialog "You must have a tab in your preferred browser (Safari) open on your roam database. Opening one for you, once open please try again"
		end if
	end if


	return
end run


script GetTick --> for more precise timer calculations
	use framework "Foundation"
	on Now()
		return (current application's NSDate's timeIntervalSinceReferenceDate) as real
	end Now
end script
