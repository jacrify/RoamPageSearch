#@osa-lang:AppleScript
#@osa-lang:AppleScript
#Roam Reuse 1.1

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


on goToSafariPage(w, u)
	#Set URL mode.
	#activate chrome window, set url
	log "Setting url of chrome"
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

on injectChromeJavascript(w, j)
	# Inject Javascript mode
	log "Injecting javascript into chrome"
	tell application "Google Chrome"
		set index of w to 1

		#So this is nuts.
		#Google chrome lets you execute javascript through applescript
		#But this javascript cannot access any page objects eg roamAlphaAPI
		#We can cheat by running our javascript through setting the window location to javascript:blah
		#and then pulling data out through session object
		#But setting url of active tab pulls chrome to front
		#So instead, we run javascript to set the location of the current tab to be a javascript that queries roamAlphaAPI and dumps into session
		#And amazingly that works

		set js to "window.location.href = \"javascript:sessionStorage.setItem('roamapihackery', " & j & ")\""
		execute front window's active tab javascript js
		set response to {execute front window's active tab javascript "sessionStorage.getItem('roamapihackery')"}
	end tell
end injectChromeJavascript

on goToChromePage(w, u)
	#Set URL mode.
	#activate chrome window, set url
	log "Setting url of chrome"
	tell application "Google Chrome"
		activate
		set index of w to 1
		if URL of active tab of w is not u then
			tell w to set URL of active tab to u
		end if
	end tell
	#this delay seems to be needed to remove timing voodo
	delay 0.1
	tell application "System Events"
		tell application process "Google Chrome"
			tell window 1
				perform action "AXRaise"
			end tell
		end tell
	end tell
end goToChromePage


#time of last run.
property lastRunTime : 0
property response : ""



on run argv
	set dbname to (system attribute "DBName")

	if (dbname is "") then
		display dialog "Please set DBName in workflow environment variables"
		return
	end if


	set preferredBrowser to (system attribute "preferredBrowser")
	if (preferredBrowser is "" or (preferredBrowser is not "Safari" and preferredBrowser is not "Chrome")) then
		display dialog "Please set preferredBrowser in workflow environment variables to either Safari or Chrome"
		return
	end if

	set mode to "goToPageByID"

	if argv is not {} then
		if item 1 of argv is "goToPageByID" then

			#target page is a page id
			set targetPage to item 2 of argv
			set mode to "goToPageByID"
		else if item 1 of argv is "goToPageByName" then


			#targetPageName is a page name
			set targetPageName to item 2 of argv

			set mode to "goToPageByName"
			#this javascript searchs for a page matching a string, and returns the block uid. It's really horrid and should be destroyed and then burned.
			set searchjavascript to "window.roamAlphaAPI.q('[:find ?e :in $ ?a :where [?e :node/title ?a]]','" & targetPageName & "').length==0 ? '':window.roamAlphaAPI.pull('[*]',window.roamAlphaAPI.q('[:find ?e :in $ ?a :where [?e :node/title ?a]]','" & targetPageName & "')[0][0])[':block/uid']"
		else if item 1 of argv is "getAllPages" then

			#get all page titles
			set targetPage to ""
			set mode to "getAllPages"
		else if item 1 of argv is "gotoDaily" then

			#go straight to daily page
			set mode to "gotoDaily"
		else
			display dialog "Unknown mode selector passed"
			retur
		end if
	end if

	#cache result if this is a query run
	if mode is "getAllPages" then
		if response is not "" then
			set cacheTimeInSeconds to (system attribute "cacheTimeInSeconds")

			#cache results for some time to make it faaaaast
			set start to GetTick's Now()
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


	#Javascript does the following:
	#Get dbids of all pages in roam database : window.roamAlphaAPI.q('[:find ?e :where [?e :node/title]]')
	#Iterate through each id and pull page details: window.roamAlphaAPI.pull('[*]', n[0])
	#Build json from title, pageid. We hack the full url we want to navigate to into the url. It's crappy but best do it here rather than in the applescript that sends the browser to the url
	#Square braces seem to throw Alfred out, so we strip them out.
	set getallpagesjavascript to "JSON.stringify({items:window.roamAlphaAPI.q('[:find ?e :where [?e :node/title]]').map(n=>{let o=window.roamAlphaAPI.pull('[*]', n[0]);return {title:o[':node/title'].replace(/[\\[\\]]/g,''),uid:o[':block/uid'],arg:o[':block/uid']}})})"



	#list of list of tab urls from all windows
	set allWindowsTabURLList to ""
	#list of list of tab titles from all windows
	set allWindowsTabTitlesList to ""
	#list of all windows, chrome first, then safari
	set allWindowsList to ""


	#check if current tab is a roam doc, if not loop through all tab



	set windowIndex to 1
	set found to false

	#stop looping when we get back to where we started, to handle cast where no tabs found

	set tabIndex to 1
	set windowsSearched to 0

	set foundWindow to ""


	if preferredBrowser is "Chrome" then

		# Check if current chrome tab is a roam tab
		tell application "Google Chrome"
			set activeURL to URL of active tab of first window
			if ((activeURL as text) contains searchString) then
				set found to true
				set foundWindow to first window

			end if
		end tell

		#if not search through all windows
		if found is not true then
			tell application "Google Chrome"
				set allWindowsList to windows
				set allWindowsTabURLList to URL of tabs of every window
				set allWindowsTabTitlesList to title of tabs of every window
			end tell

			#iterate through all windows
			repeat while windowIndex ≤ length of allWindowsTabURLList and windowIndex > 0
				set thisWindowsTabsURLs to item windowIndex of allWindowsTabURLList
				set thisWindowsTabsTitles to item windowIndex of allWindowsTabTitlesList
				#iterate through all tabs in each window
				repeat while tabIndex ≤ length of thisWindowsTabsURLs and tabIndex > 0
					set TabURL to item tabIndex of thisWindowsTabsURLs
					if ((TabURL as text) contains searchString) then
						tell application "Google Chrome"

							set foundWindow to item windowIndex of allWindowsList
							#activate this tab
							tell foundWindow to set active tab index to tabIndex
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
			else if mode is "getAllPages" then
				return injectChromeJavascript(foundWindow, getallpagesjavascript)
			end if
		end if
		if not found then
			tell application "Google Chrome"
				open location "https://" & searchString
			end tell
			display dialog "You must have a tab in your preferred browser (Chrome) open on your roam database. Opening one for you, once open please try again"
		end if
		return
	end if


	if preferredBrowser is "Safari" then
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
				tell application "Safari"
					set index of foundWindow to 1
					set pageID to (do JavaScript searchjavascript in document 1)

				end tell
				#TODO we should really check if this is not found
				set pageURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & pageID

				goToSafariPage(foundWindow, pageURL)

			else if mode is "goToPageByID" then
				set targetURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & targetPage
				goToSafariPage(foundWindow, targetURL)
			else if mode is "gotoDaily" then
				set targetURL to "https://roamresearch.com/#/app/" & dbname
				goToSafariPage(foundWindow, targetURL)
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
	end if

	if not found then
		tell application "Safari"
			open location "https://" & searchString
		end tell
		display dialog "You must have a tab in your preferred browser (Safari) open on your roam database. Opening one for you, once open please try again"
	end if
	return



	return
end run


script GetTick --> for more precise timer calculations
	use framework "Foundation"
	on Now()
		return (current application's NSDate's timeIntervalSinceReferenceDate) as real
	end Now
end script
