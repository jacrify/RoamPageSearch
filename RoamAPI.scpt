#@osa-lang:AppleScript
#@osa-lang:AppleScript
#Roam Reuse 2.0

#Copyright 2020, John Cranney
#Copying and distribution of this file, with or without modification, are permitted in any medium without royalty, provided the copyright notice and this notice are preserved. This file is offered as-is, without any warranty.


#See https://www.putyourleftfoot.in/roampagesearch

global browsername
global keydelay

#time of last run.
property lastRunTime : 0
#cached response
property allPagesResponse : ""

#remove this later and pass around

###################################################################
# Utility functions
###################################################################

on replace_chars(this_text, search_string, replacement_string)
	set AppleScript's text item delimiters to the search_string
	set the item_list to every text item of this_text
	set AppleScript's text item delimiters to the replacement_string
	set this_text to the item_list as string
	set AppleScript's text item delimiters to ""
	return this_text
end replace_chars

on oneline(s)
	return replace_chars(replace_chars(s, "
	", ""), "	", "")
end oneline

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

on injectChromeJavascript(w, j, t)
	# Inject Javascript mode'

	log "Injecting javascript into chrome"
	using terms from application "Google Chrome"
		tell application browsername
			#set index of w to 1

			#So this is nuts.
			#Google chrome lets you execute javascript through applescript
			#But this javascript cannot access any page objects eg roamAlphaAPI
			#We can cheat by running our javascript through setting the window location to javascript:blah
			#and then pulling data out through session object
			#But setting url of active tab pulls chrome to front
			#So instead, we run javascript to set the location of the current tab to be a javascript that queries roamAlphaAPI and dumps into session
			#And amazingly that works
			#set js to "window.location.href = \"javascript:sessionStorage.setItem('roamapihackery', " & j & ")\""
			#set mytab to tab t of the front window
			set js to "window.location.href = \"javascript:" & j & ";sessionStorage.setItem('roamapihackery', jsreturn)\""
			#execute mytab javascript js
			log "TITLE:" & title of t
			#execute t javascript "sessionStorage.setItem('roamapihackery','')"

			#set js to "window.location.href = \"javascript:alert('here')\""
			#set js to "window.location.href = \"javascript:sessionStorage.setItem('roamapihackery', 'boo')\""
			log "Executing javascript in chrome as follows
			" & js
			execute t javascript js

			return {execute t javascript "sessionStorage.getItem('roamapihackery')"}
		end tell
	end using terms from
end injectChromeJavascript

on goToChromePage(w, u, t)

	#Set URL mode.
	#activate chrome window, set url
	log "Setting url of chrome"
	using terms from application "Google Chrome"
		tell application browsername
			activate
			if t is not -1 then
				tell w to set active tab index to t
			end if
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

	if ((system attribute "addtimestamp") is "true") then
		set addtimestamp to true
	else
		set addtimestamp to false
	end if

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

	if mode is "" then
		set mode to "getAllPages"
	end if

	if mode is "goToPageByID" then
		#target page is a page id
		set targetPage to item 1 of argv

	else if mode is "goToPageByName" then

		#targetPageName is a page name
		set targetPageName to item 1 of argv

		#this javascript searchs for a page matching a string, and returns the block uid..

		set searchjavascript to "jsreturn=window.roamAlphaAPI.q('[:find (pull ?e [[:node/title] [:block/uid]] )  :in $ ?a :where [?e :node/title ?a]]','" & targetPageName & "').map(n=>n.map(n=>n['uid'])).join('')"

	else if mode is "getAllPages" then
		#get all page titles
		set targetPage to ""
		#Javascript does the following:
		#Get dbids of all pages in roam database : window.roamAlphaAPI.q('[:find ?e :where [?e :node/title]]')
		#Iterate through each id and pull page details: window.roamAlphaAPI.pull('[*]', n[0])
		#Build json from title, pageid. We hack the full url we want to navigate to into the url. It's crappy but best do it here rather than in the applescript that sends the browser to the url
		#Square braces seem to throw Alfred filtering out, so we strip them out.

		#pulls backlinks using :block_ref expression !
		#would be nice to pull count of outbound links, but it's too slow.
		set getallpagesjavascript to oneline("
			{jsreturn =JSON.stringify(
			{items:
				window.roamAlphaAPI
				.q('[
					:find (pull ?e [
						[:node/title]
						[:block/children]
						[:block/refs]
						[:block/uid]
						{:block/_refs [:db/id :block/uid]}
					])
					:in 	$
						%
					:where [?e :node/title]]'
					," & ancestorrule & ")
				.map(n=>
					{return {
						title:n[0]['title'],
						subtitle:'(⏎ goto, ⌘ inbound links, ⌥ outbound links, ⇧ paste content )',
						match:n[0]['title']" & bracestrip & ",
						uid:n[0]['uid'],
						arg:n[0]['title'],
						text:{copy:'[['+n[0]['title']+']]'},
						mods:{
							cmd: {
								valid:(n[0]['_refs']!=undefined),
								subtitle: (n[0]['_refs']!=undefined)?'Show pages that link here':'Nothing links to this page'
								}
							,
							alt: {
								valid:true,
								subtitle: 'Show pages linked from here'
								}
							}
					}}
					)
			})}")


	else if mode is "getPagesWithTag" then

		set targetPage to ""
		set targetTag to item 1 of argv

		set getallpagesjavascript to oneline("
			jsreturn =JSON.stringify(
				{items:
					window.roamAlphaAPI
					.q('[
						:find (pull ?targetpage [
							[:node/title]
							[:block/refs]
							{:block/_refs [:db/id :block/uid]}
							[:block/uid]] )
						:in $
							?searchstring
							%
						:where
							[?tagpage :node/title ?searchstring]
							[?anyblock :block/refs ?tagpage]
							[?targetpage :node/title]
							(ancestor ?anyblock ?targetpage)
							]','
						" & targetTag & "'," & ancestorrule & ")
					.map(n=>
					{return {
						title:n[0]['title'],
						subtitle:'(⏎ goto, ⌘ inbound links, ⌥ outbound links, ⇧ paste content )',
						match:n[0]['title']" & bracestrip & ",
						uid:n[0]['uid'],
						arg:n[0]['title'],
						text:{copy:'[['+n[0]['title']+']]'},
						mods:{
							cmd: {
								valid:(n[0]['_refs']!=undefined),
								subtitle: (n[0]['_refs']!=undefined)?'Show pages that link here':'Nothing links to this page'
								}
							,
							alt: {
								valid:true,
								subtitle: 'Show pages linked from here'
								}
							}
					}}
					)
				})")



	else if mode is "getTagsOfPage" then

		set targetPage to ""
		set targetTag to item 1 of argv

		set getallpagesjavascript to oneline("
			jsreturn =JSON.stringify(
				{items:
					window.roamAlphaAPI
						.q('[
							:find (pull ?targetpage [
								[:node/title]
								[:block/uid]
								[:block/refs]
								{:block/_refs [:db/id :block/uid]}
							] )
							:in
								$
								?searchstring
								%
							:where
								[?containingpage :node/title ?searchstring]
								[?anyblock :block/refs ?targetpage]
								[?targetpage :node/title]
								(ancestor ?anyblock ?containingpage)]','
							" & targetTag & "'," & ancestorrule & ")
						.map(n=>
							{return {
								title:n[0]['title'],
								subtitle:'(⏎ goto, ⌘ inbound links, ⌥ outbound links, ⇧ paste content )',
								match:n[0]['title']" & bracestrip & ",
								uid:n[0]['uid'],
								arg:n[0]['title'],
								text:{copy:'[['+n[0]['title']+']]'},
								mods:{
									cmd: {
										valid:(n[0]['_refs']!=undefined),
										subtitle: (n[0]['_refs']!=undefined)?'Show pages that link here':'Nothing links to this page'
										}
									,
									alt: {
										valid:true,
										subtitle: 'Show pages linked from here'
										}
									}
							}}
							)
				})")



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

		#dynamically generate subtitle
		set enterstring to "⏎"
		if pastemode then
			set enterstring to enterstring & "paste to block on daily page"
		else
			set enterstring to enterstring & "jump to block on daily page"
		end if

		if addtodo then
			set enterstring to enterstring & ", making todo"
		end if
		if addtimestamp then
			set enterstring to enterstring & ", adding timestamp"
		end if

		set getconfigpagejavascript to oneline("
			jsreturn =JSON.stringify(
				{items:
					window.roamAlphaAPI
						.q('[
							:find (pull ?optionblock [
								[:block/string]
								[:block/children]])
							:in
								$
								?configpagetitle
								?menublockstring
								%
							:where
								[?configpage :node/title ?configpagetitle]
								[?menublock :block/string ?menublockstring]
								(ancestor ?menublock ?configpage)
								[?menublock :block/children ?optionblock]
							  ]', '" & configPageName & "','" & targetblock & "', " & ancestorrule & " )
							.map(n=> {
								return {
									title: n[0].string" & bracestrip & ",
									subtitle:  (n[0].children!=undefined)?'" & enterstring & " or ⌥ show children':'" & enterstring & "',
									arg:n[0].string,
									text:{copy:'[['+n[0].string+']]'},
										mods:{
											alt: {
													valid:(n[0].children!=undefined),
													subtitle: (n[0].children!=undefined)?'Show children blocks':'No child blocks on config page'
												}
											}
									}})
					})")




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


	else if mode is "getConfigPageNames" then

		set targetPage to ""
		#TODO error handle this not being there
		set targetblock to item 1 of argv

		#Javascript does the following:
		#find page called RoamSearchConfig
		#find block on page with contents = targetblock
		#return names of pages each child of targetblock references
		# only one reference is returned per child (the oldest). This means [[[[foo]][[bar]]]] should return [[foo]][[[bar]]
		# it's assume the oldest is the last in the array of refs
		# we count rerences to each of the final refs to find whether there are inbound links or not.

		#arg passed to alfred is the full string tag
		set getconfigpagejavascript to oneline("
			jsreturn =JSON.stringify(
				{items:
					window.roamAlphaAPI
						.q('[
							:find (pull ?optionblock [
								[:block/string]
								[:block/refs]
								[:block/uid]
								{:block/refs [:node/title]}])
							:in
								$
								?configpagetitle
								?menublockstring
								%
							:where
								[?configpage :node/title ?configpagetitle]
								[?menublock :block/string ?menublockstring]
								[?menublock :block/children ?optionblock]
								(ancestor ?menublock ?configpage)
							]', '" & configPageName & "','" & targetblock & "', " & ancestorrule & ")
						.filter(b=>b[0].refs!=undefined)
						.map(b=>
							b[0].refs.slice(-1)[0])
						.map(b=>{return {hasinboundlinks:window.roamAlphaAPI.q('[ :find (count ?b)  :with ?e :in $ ?myid  :where [?e :node/title ?myid] [?b :block/refs ?e] ] ',b.title)[0][0]>0,title:b.title,uid:b.uid}})
						.map(n=>
							{return {
								title:n['title'],
								subtitle:'(⏎ goto, ⌘ inbound links, ⌥ outbound links, ⇧ paste content )',
								match:n['title']" & bracestrip & ",
								uid:n['uid'],
								arg:n['title'],
								text:{copy:'[['+n['title']+']]'},
								mods:{
									cmd: {
										valid:n.hasinboundlinks,
										subtitle: n.hasinboundlinks?'Show pages that link here':'Nothing links to this page'
										}
									,
									alt: {
										valid:true,
										subtitle: 'Show pages linked from here'
										}
									}
							}}
							)
					})")


	else if mode is "pastePageContent" then

		set targetPage to item 1 of argv

		#the following from https://gist.github.com/thesved/79371d0c1dd34b6750c846368b323113 thanks to Viktor Tabori
		set getPageContent to "function resolveNode(r,e,i,o,n,a){e=e||0,i=Object.assign({},i);var l=n?'':' '.repeat(2*Math.max(e-1,0))+'- ',t=n&&a?'':'@@@!!!@@@',d='';if(!i[r]){i[r]=!0;var c=window.roamAlphaAPI.pull('[*]',r),s=c[':block/order']||0;if(c[':block/heading']&&c[':block/heading']>0&&(l+='#'.repeat(c[':block/heading'])+' '),void 0!==c[':block/string']){var b=o?/!?{{\\[*embed\\]*\\s*:\\s*\\(\\(([^\\)]*)\\)\\)\\s*}}/gi:/!{{\\[*embed\\]*\\s*:\\s*\\(\\(([^\\)]*)\\)\\)\\s*}}/gi;c[':block/string']=c[':block/string'].replace(b,function(r,o){var n=o.trim(),a=window.roamAlphaAPI.q('[:find ?e :in $ ?a :where [?e :block/uid ?a]]',n);if(0==a.length)return r;var l=resolveNode(a[0][0],e,i,!0,!0);return void 0!==l?l:'LOOP:'+r});var v=o?/!?\\(\\(([^\\)]*)\\)\\)/gi:/!\\(\\(([^\\)]*)\\)\\)/gi;c[':block/string']=c[':block/string'].replace(v,function(r,o){var n=o.trim(),a=window.roamAlphaAPI.q('[:find ?e :in $ ?a :where [?e :block/uid ?a]]',n);if(0==a.length)return r;var l=resolveNode(a[0][0],e,i,!0,!0,!0);return void 0!==l?l:'LOOP:'+r}),d+=l+c[':block/string']+t}if(c[':block/children']&&!a){var g,u=[];for(var h in c[':block/children'])void 0!==(g=resolveNode(c[':block/children'][h][':db/id'],e+1,i))&&u.push(g);u.sort(function(r,e){return r.order-e.order}),d+=u.map(function(r){return r.txt}).join('')}return 0==e||n?d:{txt:d,order:s}}};var node = window.roamAlphaAPI.q('[ :find (pull ?e [*]) :in $ ?t :where [?e :node/title ?t]] ','" & targetPage & "'); if (node.length>0) { let id=node[0][0].id; jsreturn=resolveNode(id);}"

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
		set quickentryjavascript to oneline("
			{let tempout=
				window.roamAlphaAPI
					.q('[
						:find (pull ?dailypageblock
							 [:block/uid])
						:in
							$
							?dailypagetitle
							?tagtitle
							%
						:where
							[?dailypageblock :block/string ?tagtitle]
							[?dailypage :block/uid ?dailypagetitle]
							(ancestor ?dailypageblock ?dailypage)
					]','" & dailyDate & "','" & targetTag & "'," & ancestorrule & "
					);
					if (tempout.length>0) {
						jsreturn=tempout[0][0].uid
					} else {
						jsreturn ='notfound'
					}}")

	else
		display dialog "Unknown mode selector passed"
		return
	end if


	#cache result if this is a query run
	if mode is "getAllPages" then
		if allPagesResponse is not "" then
			set cacheTimeInSeconds to (system attribute "cacheTimeInSeconds") as number
			#cache results for some time to make it faaaaast
			set timeSinceLastRun to start - lastRunTime
			set lastRunTime to start

			if (lastRunTime is not 0) and (timeSinceLastRun < cacheTimeInSeconds) then
				return allPagesResponse
			end if
		end if
	end if



	set windowIndex to 1
	#current tab being scanned
	set tabindex to 0


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
	set tabindex to 1
	set windowsSearched to 0

	set foundWindow to ""
	set foundtab to 0



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
					set foundtab to active tab of first window
					#indicate not to switch tabs
					set tabindex to -1
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
					set allWindowsTabs to tabs of every window
				end tell
			end using terms from
			#iterate through all windows
			repeat while windowIndex ≤ length of allWindowsTabURLList and windowIndex > 0
				set thisWindowsTabsURLs to item windowIndex of allWindowsTabURLList
				set thisWindowsTabsTitles to item windowIndex of allWindowsTabTitlesList
				set thisWindowsTabs to item windowIndex of allWindowsTabs
				#iterate through all tabs in each window
				repeat while tabindex ≤ length of thisWindowsTabsURLs and tabindex > 0
					set TabURL to item tabindex of thisWindowsTabsURLs
					if ((TabURL as text) contains searchString) then
						log "tabindex " & (tabindex as string)
						using terms from application "Google Chrome"
							tell application browsername
								set foundtab to item tabindex of thisWindowsTabs
								set foundWindow to item windowIndex of allWindowsList
								#activate this tab. This brings window to front which is annoying.
								# tell foundWindow to set active tab index to tabindex
							end tell
						end using terms from
						set found to true
						exit repeat
					end if
					set tabindex to tabindex + 1
				end repeat

				if found then exit repeat

				set tabindex to 1
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
			log "tabindex " & (tabindex as string)
			if mode is "goToPageByName" then
				#find the page uid
				set pageID to injectChromeJavascript(foundWindow, searchjavascript, foundtab)
				#TODO we should really check if this is not found
				set pageURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & pageID

				goToChromePage(foundWindow, pageURL, tabindex)
				#end if

			else if mode is "gotoDaily" then
				set targetURL to "https://roamresearch.com/#/app/" & dbname
				goToChromePage(foundWindow, targetURL, tabindex)

			else if mode is "goToPageByID" then
				set targetURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & targetPage
				goToChromePage(foundWindow, targetURL, tabindex)
			else if mode is "pastePageContent" then
				set resp to injectChromeJavascript(foundWindow, getPageContent, foundtab)
				return resp
			else if mode is "quickEntryDaily" then
				set targetURL to "https://roamresearch.com/#/app/" & dbname

				set pageID to injectChromeJavascript(foundWindow, quickentryjavascript, foundtab)

				if (pageID as string) is equal to "notfound" then
					#add tag to daily notes page
					goToChromePage(foundWindow, targetURL, tabindex)
					addToTopOfPage(targetTag, textToEnter, pastemode, addtodo)
				else
					set pageURL to "https://roamresearch.com/#/app/" & dbname & "/page/" & pageID
					goToChromePage(foundWindow, pageURL, tabindex)
					focusBottomOfPage(textToEnter, pastemode, addtodo)
				end if

			else if mode is "getConfigPageData" or mode is "getConfigPageNames" then
				set resp to injectChromeJavascript(foundWindow, getconfigpagejavascript, foundtab)

				if resp is "{\"items\":[]}" then
					display dialog "Menu configuration tag not found on RoamSearchConfig page. Read the docs :)"
				end if
				log "Config loaded from roam. Resp :" & resp
				return resp

			else if mode is "getAllPages" or mode is "getPagesWithTag" or mode is "getTagsOfPage" then

				set r to injectChromeJavascript(foundWindow, getallpagesjavascript, foundtab)

				if mode is "getAllPages" then
					set allPagesResponse to r
				end if

				return r
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
				repeat while tabindex ≤ length of thisWindowsTabsURLs and tabindex > 0
					set TabURL to item tabindex of thisWindowsTabsURLs
					if ((TabURL as text) contains searchString) then
						tell application "Safari"
							set foundWindow to item windowIndex of allWindowsList
							#activate this tab
							tell foundWindow to set current tab to tab tabindex
						end tell
						set found to true
						exit repeat
					end if
					set tabindex to tabindex + 1
				end repeat

				if found then exit repeat

				set tabindex to 1
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
			else if mode is "pastePageContent" then
				set resp to injectSafariJavascript(foundWindow, getPageContent, foundtab)
				return resp
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

			else if mode is "getAllPages" or mode is "getPagesWithTag" or mode is "getTagsOfPage" then
				# Inject Javascript mode
				log "Injecting javascript into safari"
				tell application "Safari"
					set index of foundWindow to 1
					set response to (do JavaScript getallpagesjavascript in document 1)
					if mode is "getAllPages" then
						set allPagesResponse to response
					end if
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
