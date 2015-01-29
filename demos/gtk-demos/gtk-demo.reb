REBOL []

glib: do %../bindings/glib.reb
gtk: do %../bindings/gtk.reb

debug: :comment
debug: :print

global-mem-pool: copy []

libc: make library! %libc.so.6

strlen: make routine! compose [[
	ptr [pointer]
	return: [uint64]
] (libc) "strlen"]

mk-cb: func [
	args [block!]
	body [block!]
	/extern words [block!]
	/local r-args arg a tmp-func
][
	r-args: copy []

	arg:[
		copy a word! (append r-args a)
		block!
		opt string!
	]
	attr: [
		set-word!
		block! | word!
	]

	parse args [
		opt string!
		some [ arg | attr ]
	]

	;debug ["args:" mold args]

	either extern [
		tmp-func: function/extern r-args body words
	][
		tmp-func: function r-args body
	]

	;debug ["tmp-func:" mold :tmp-func]
	make callback! compose/deep [[(args)] :tmp-func]
]

r2utf8-string: function [
	s [string!]
][
	s-s: make struct! compose/deep [ uint8 [(1 + length? s)] s]
	change s-s join to binary! s #{00}
	s-s
]

utf82r-string: function [
	s [integer!]
][
	len: strlen s
	debug ["len:" len]
	s-s: make struct! compose/deep [[raw-memory: (s)] uint8 [(len)] s]
	to string! values-of s-s
]

activate-about: mk-cb [
	action 		[pointer]
	parameter 	[pointer]
	user-data	[pointer]
	return: [void]
][
	debug ["activate-about"]
]

activate-quit: mk-cb [
	action 		[pointer]
	parameter 	[pointer]
	user-data	[pointer]
	return: [void]
][
	debug ["activate-quit"]
]

startup: mk-cb/extern [
	app [pointer]
][
	debug ["startup"]
	s-ui-main: r2utf8-string "/ui/main.ui"
	s-app-menu: r2utf8-string "appmenu"

	append global-mem-pool reduce [s-ui-main s-app-menu]

	ids: make struct! [
		pointer [2] data: reduce [addr-of s-app-menu 0]
	]

	builder: gtk/builder_new
	gtk/builder_add_objects_from_resource builder (addr-of s-ui-main) (addr-of ids) 0

	app-menu: gtk/builder_get_object builder addr-of s-app-menu

	gtk/application_set_app_menu app app-menu

	glib/object_unref builder
][
	global-mem-pool
]

activate-run: mk-cb [
][
	debug ["activate-run"]
]

row-activated-cb: mk-cb [
][
	debug ["row-activated-cb"]
]

selection-cb: mk-cb [
][
	debug ["selection-cb"]
]

activate: mk-cb/extern [
	app [pointer]
][
	debug ["activate"]
	s-run: r2utf8-string "run"
	s-ui-main: r2utf8-string "/ui/main.ui"
	s-window: r2utf8-string "window"
	s-notebook: r2utf8-string "notebook"
	s-info-textview: r2utf8-string "info-textview"
	s-source-textview: r2utf8-string "source-textview"
	s-headerbar: r2utf8-string "headerbar"
	s-treeview: r2utf8-string "treeview"
	s-row-activated: r2utf8-string "row-activated"
	s-treeview-selection: r2utf8-string "treeview-selection"
	s-changed: r2utf8-string "changed"

	error: make struct! compose [
		pointer data
	]

	append global-mem-pool reduce [
		s-run s-ui-main s-window
		s-notebook s-info-textview s-source-textview
		s-headerbar s-treeview s-row-activated
		s-treeview-selection s-changed
	]

	action-entry: make glib/GActionEntry compose [
		name: (addr-of s-run)
		activate: (addr-of activate-run)
	]

	win-entries: make struct! compose compose/deep[
		(glib/GActionEntry) [1] entry: [(action-entry)]
	]

	builder: gtk/builder_new
	gtk/builder_add_from_resource builder (addr-of s-ui-main) (addr-of error)

	unless zero? error/data [
		error-val: make glib/GError compose/deep [
			[raw-memory: (error/data)]
		]
		s-format: r2utf8-string "%s"
		glib/log reduce [ 0 glib/GLogLevelFlags/G_LOG_LEVEL_CRITICAL
			addr-of s-format
			error-val/message [pointer]
		]
		debug ["quitting"]
		quit
	]

	window: gtk/builder_get_object builder addr-of s-window
	gtk/application_add_window app window

	glib/action_map_add_action_entries
		window
		addr-of win-entries
		((length? win-entries) / (length? glib/GActionEntry))

	notebook: gtk/builder_get_object builder addr-of s-notebook
	info-textview: gtk/builder_get_object builder addr-of s-info-textview
	source-textview: gtk/builder_get_object builder addr-of s-source-textview
	headerbar: gtk/builder_get_object builder addr-of s-headerbar
	treeview: gtk/builder_get_object builder addr-of s-treeview
	model: gtk/tree_view_get_model treeview

	;load-file ;FIXME

	glib/signal_connect treeview addr-of s-row-activated addr-of row-activated-cb model

	widget: gtk/builder_get_object builder addr-of s-treeview-selection
	glib/signal_connect widget addr-of s-changed addr-of selection-cb model

	gtk/widget_show_all window
	glib/object_unref builder
][
	global-mem-pool
]

init-resource: function [
][
	s-resource: r2utf8-string "demo.gresource"
	error: make struct! compose [
		pointer data
	]
	resource: glib/resource_load addr-of s-resource addr-of error
	unless zero? error/data [
		error-val: make glib/GError compose/deep [
			[raw-memory: (error/data)]
		]
		s-format: r2utf8-string "%s"
		glib/log reduce [ 0 glib/GLogLevelFlags/G_LOG_LEVEL_CRITICAL
			addr-of s-format
			error-val/message [pointer]
		]
		debug ["quitting"]
		quit
	]

	glib/resources_register resource
]

main: function/extern [
	argc [integer!]
	argv [integer!]
][
	init-resource

	s-about: r2utf8-string "about"
	s-quit: r2utf8-string "quit"

	about-entry: make glib/GActionEntry compose [
		name: (addr-of s-about)
		activate: (addr-of activate-about)
	]

	debug ["addr-of s-about:" addr-of s-about]
	debug ["about-entry/name:" about-entry/name]
	;debug ["s-about:" utf82r-string about-entry/name]

	quit-entry: make glib/GActionEntry compose [
		name: (addr-of s-quit)
		activate: (addr-of activate-quit)
	]

	app-entries: make struct! compose/deep/only [
		(glib/GActionEntry) [2] entries: (reduce [about-entry quit-entry])
	]

	debug ["length of app-entries in bytes:" length? app-entries]
	debug ["length of GActionEntry in bytes:" length? glib/GActionEntry]
	app-domain: to binary! "org.gtk.Demo"
	app: gtk/application_new
		app-domain
		glib/GApplicationFlags/G_APPLICATION_NON_UNIQUE

	glib/action_map_add_action_entries
		app
		addr-of app-entries
		((length? app-entries) / (length? glib/GActionEntry))
		app
	
	debug ["connect startup"]
	s-startup: r2utf8-string "startup"
	glib/signal_connect app addr-of s-startup addr-of startup 0

	debug ["connect activate"]
	s-activate: r2utf8-string "activate"
	glib/signal_connect app addr-of s-activate addr-of activate 0

	debug ["calling application_run"]
	app-val: make glib/GApplication compose/deep [
		[raw-memory: (app)]
	]
	glib/application_run app argc argv
][
	activate
]

argv-data: compose [
	(r2utf8-string "gtk-demo.reb")
]

; main script starts here
argv-ptr: copy []
foreach v argv-data [append argv-ptr addr-of v]
append argv-ptr 0

argc: length? argv-data

argv: make struct! compose/deep/only [
	pointer [(1 + argc)] data: (argv-ptr)
]

main argc addr-of argv
;main 0 0
