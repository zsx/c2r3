REBOL []

;recycle/torture
glib: do %../../bindings/glib.reb
pango: do %../../bindings/pango.reb
gtk: do %../../bindings/gtk.reb

debug: :comment
debug: :print

global-mem-pool: copy []
current-file: _
notebook:
info-textview:
source-textview:
treeview:
headerbar: _

libc: make library! %libc.so.6

strlen: make-routine libc "strlen" [
	ptr [pointer]
	return: [uint64]
]

mk-cb: :make-callback

r2utf8-string: function [
	s [string!]
][
	s-s: make struct! compose/deep [ s [uint8 [(1 + length? s)]]]
	change s-s join-of to binary! s #{00}
	s-s
]

utf82r-string: function [
	s [integer!]
][
	len: strlen s
	debug ["len:" len]
	s-s: make struct! compose/deep [[raw-memory: (s)] s [uint8 [(len)]]]
	to string! values-of s-s
]

do %builder.reb
do %css-accordion.reb

NAME_COLUMN: 0
TITLE_COLUMN: 1
FILENAME_COLUMN: 2
FUNC_COLUMN: 3
STYLE_COLUMN: 4
NUM_COLUMNS: 5

callback-data: make struct! [
	model [pointer]
	path [pointer]
]

demos: reduce [
	context [
		name: "builder"
		title: "Builder"
		filename: "builder.reb"
		demo-func: make struct! [
			f: [rebval] :do-builder
		]
		children: _
	]
	context [
		name: _
		title: "CSS Theming"
		filename: _
		demo-func: _
		children: reduce [
			context [
				name: "css_accordion"
				title: "CSS Accordion"
				filename: "css-accordion.reb"
				demo-func: make struct! [
					f: [rebval] :do-css-accordion
				]
				children: _
			]
		]
	]
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

window-closed-cb: mk-cb [
	window 	[pointer]
	data 	[pointer]
    <with>
        callback-data
        global-mem-pool
][
	cbdata: make-similar-struct callback-data compose/deep [
		[raw-memory: (data)]
	]

	style: make struct! [i [int32]]

	iter: make-similar-struct gtk/GtkTreeIter []
	gtk/tree_model_get_iter cbdata/model addr-of iter cbdata/path

	gtk/tree_model_get
		cbdata/model
		addr-of iter
		STYLE_COLUMN [int32]
		addr-of style [pointer]
		-1 [int32]
	|

	if style/i = pango/PangoStyle/PANGO_STYLE_ITALIC [
		gtk/tree_store_set
			cbdata/model
			addr-of iter
			STYLE_COLUMN [int32]
			pango/PangoStyle/PANGO_STYLE_NORMAL [int32]
			-1 [int32]
		|
	]

	gtk/tree_path_free cbdata/path

	comment [;TODO free memory
		foreach [i:] global-mem-pool [
			if struct? first i [
				if model = get first i 'model [
					remove i
				]
			]
		]
	]
]

startup: mk-cb [
	app [pointer]
    <with>
        global-mem-pool
][
	debug ["startup"]
	s-ui-main: r2utf8-string "/ui/main.ui"
	s-app-menu: r2utf8-string "appmenu"

    dump s-ui-main
    dump s-app-menu

    print ["addr-of s-ui-main" addr-of s-ui-main]
	append global-mem-pool reduce [s-ui-main s-app-menu]

	ids: make struct! compose/deep [
		data: [pointer [2]] [(addr-of s-app-menu) 0]
	]

    dump ids

	builder: gtk/builder_new
	gtk/builder_add_objects_from_resource builder (addr-of s-ui-main) (addr-of ids) 0

	app-menu: gtk/builder_get_object builder addr-of s-app-menu

	gtk/application_set_app_menu app app-menu

	glib/object_unref builder
]

run-example-for-now: procedure [
	window	[integer!]
	model	[integer!]
	iter	[integer!]
    <with>
	global-mem-pool
][
	func-addr: make struct! [ ptr [pointer] ]
	style: make struct! [i [int32]]

	debug ["run-example-for-now, model:" to-hex model "iter:" to-hex iter "addr-of style" addr-of style]

	gtk/tree_model_get
		model
		iter
		FUNC_COLUMN [int32]
		(addr-of func-addr) [pointer]
		STYLE_COLUMN [int32]
		(addr-of style) [pointer]
		-1 [int32]
	|
	debug ["tree_model_get done"]

	;debug ["func-addr/ptr:" func-addr/ptr]

	unless zero? func-addr/ptr [
		f: make struct! compose/deep [
			[raw-memory: (func-addr/ptr)]
			f [rebval]
		]

		gtk/tree_store_set
			model
			iter
			STYLE_COLUMN [int32]
			either style/i = pango/PangoStyle/PANGO_STYLE_ITALIC [
				pango/PangoStyle/PANGO_STYLE_NORMAL
			][
				pango/PangoStyle/PANGO_STYLE_ITALIC
			] [int32]
			-1 [int32]
		|

		;debug ["f/f:" mold :f/f]
		demo: f/f window
		;debug ["demo:" mold demo]

		unless zero? demo [
			cbdata: make-similar-struct callback-data reduce/no-set [
				model: model
				path: gtk/tree_model_get_path model iter
			]
			append global-mem-pool cbdata

			if gtk/widget_is_toplevel demo [
				gtk/window_set_transient_for demo window
				gtk/window_set_modal demo 1
			]

			glib/signal_connect demo (addr-of r2utf8-string "destroy")
								(addr-of :window-closed-cb)
								addr-of cbdata

		]
	]
]

activate-run: mk-cb [
	action 		[pointer]
	parameter 	[pointer]
	user-data	[pointer]
    <with> treeview
][
	debug ["activate-run"]
	model: make struct! [model [pointer]]
	iter: make-similar-struct gtk/GtkTreeIter []

	selection: gtk/tree_view_get_selection treeview
	gtk/tree_selection_get_selected selection (addr-of model) (addr-of iter)
	run-example-for-now user-data model/model (addr-of iter)
]

row-activated-cb: mk-cb [
	tree-view 	[pointer]
	path 		[pointer]
	column		[pointer]
][
	debug ["row-activated-cb"]

	iter: make-similar-struct gtk/GtkTreeIter []
	window: gtk/widget_get_toplevel tree-view
	model: gtk/tree_view_get_model tree-view
	debug ["run-example-for-now, tree-view" to-hex tree-view "model:" to-hex model "iter:" to-hex addr-of iter]
	gtk/tree_model_get_iter model addr-of iter path

	run-example-for-now window model addr-of iter
]

selection-cb: mk-cb [
	selection 	[pointer]
	model 		[pointer]
    <with>
	    headerbar
][
	debug ["selection-cb"]

	iter: make-similar-struct gtk/GtkTreeIter []
	if zero? gtk/tree_selection_get_selected selection 0 (addr-of iter) [return]

	name: make struct! [addr [pointer]]
	title: make struct! [addr [pointer]]
	filename: make struct! [addr [pointer]]
 	gtk/tree_model_get
		model (addr-of iter)
		NAME_COLUMN [int32]
		(addr-of name) [pointer]
		TITLE_COLUMN [int32]
		(addr-of title) [pointer]
		FILENAME_COLUMN [int32]
		(addr-of filename) [pointer]
		-1 [int32]
	|

	unless zero? filename/addr [
		load-file (utf82r-string name/addr) (utf82r-string filename/addr)
	]

	gtk/header_bar_set_title headerbar (utf82r-string title/addr)
]

;dump selection-cb

create-text: function [
	is-source [logic!]
][
	scrolled-window: gtk/scrolled_window_new 0 0
	gtk/scrolled_window_set_policy scrolled-window
		gtk/GtkPolicyType/GTK_POLICY_AUTOMATIC
		gtk/GtkPolicyType/GTK_POLICY_AUTOMATIC

	gtk/scrolled_window_set_shadow_type scrolled-window
		gtk/GtkShadowType/GTK_SHADOW_NONE
	
	text-view: gtk/text_view_new

	left-margin: r2utf8-string "left-margin"
	right-margin: r2utf8-string "right-margin"
	glib/object_set 
		text-view
		(addr-of left-margin) 20 [int32]
		(addr-of right-margin) [pointer] 20 [int32]
		0 [pointer]
    |

	gtk/text_view_set_editable text-view 0
	gtk/text_view_set_cursor_visible text-view 0

	gtk/container_add scrolled-window text-view

	either is-source [
		;gtk/text_view_set_monospace text-view true
		gtk/text_view_set_wrap_mode text-view gtk/GtkWrapMode/GTK_WRAP_NONE
	][
		; make it a bit nicer for text
		gtk/text_view_set_wrap_mode text-view gtk/GtkWrapMode/GTK_WRAP_WORD
		gtk/text_view_set_pixels_above_lines text-view 2
		gtk/text_view_set_pixels_below_lines text-view 2
	]

	reduce [scrolled-window text-view]
]

populate-model: function [
	model [integer!]
    <with>
        demos
        NAME_COLUMN
        TITLE_COLUMN
        FILENAME_COLUMN
        FUNC_COLUMN
        STYLE_COLUMN
        NUM_COLUMNS
][
	foreach demo demos [
		unless blank? demo/title [
			either blank? demo/name [
				param-name: 0
			][
				name: r2utf8-string demo/name
				param-name: addr-of name
			]
			title: r2utf8-string demo/title
			either blank? demo/filename [
				param-filename: 0
			][
				filename: r2utf8-string demo/filename
				param-filename: addr-of filename
			]
			either blank? :demo/demo-func [
				param-demo-func: 0
			][
				param-demo-func: addr-of :demo/demo-func
			]
			title: r2utf8-string demo/title
			iter: make-similar-struct gtk/GtkTreeIter []
			gtk/tree_store_append model (addr-of iter) 0
			gtk/tree_store_set
				model
				addr-of iter
				NAME_COLUMN [int32]
				param-name [pointer]
				TITLE_COLUMN [int32]
				(addr-of title) [pointer]
				FILENAME_COLUMN [int32]
				param-filename [pointer]
				FUNC_COLUMN [int32]
				param-demo-func [pointer]
				STYLE_COLUMN [int32]
				pango/PangoStyle/PANGO_STYLE_NORMAL [int32]
				-1 [int32]
			|

			unless blank? demo/children [
				foreach child demo/children [
					unless blank? child/title [
						either blank? child/name [
							param-name: 0
						][
							name: r2utf8-string child/name
							param-name: addr-of name
						]
						title: r2utf8-string child/title
						either blank? child/filename [
							param-filename: 0
						][
							filename: r2utf8-string child/filename
							param-filename: addr-of filename
						]
						either blank? :child/demo-func [
							param-demo-func: 0
						][
							param-demo-func: addr-of :child/demo-func
						]
						child-iter: make-similar-struct gtk/GtkTreeIter []
						gtk/tree_store_append model (addr-of child-iter) (addr-of iter)
						gtk/tree_store_set
							model
							addr-of child-iter
							NAME_COLUMN [int32]
							param-name [pointer]
							TITLE_COLUMN [int32]
							(addr-of title) [pointer]
							FILENAME_COLUMN [int32]
							param-filename [pointer]
							FUNC_COLUMN [int32]
							param-demo-func [pointer]
							STYLE_COLUMN [int32]
							pango/PangoStyle/PANGO_STYLE_NORMAL [int32]
							-1 [int32]
						|
					]
				]
			]
		]
	]
]

remove-data-tabs: func [] [
	debug ["notebook:" notebook]
	i: (gtk/notebook_get_n_pages notebook) - 1
	while [i > 1] [
		gtk/notebook_remove_page notebook i
		i: -- 1
	]
]

add-data-tab: procedure [
	demoname [any-string!]
    <with>
	    notebook
][
	resource-dir: join-of "/" demoname
	s-resource-dir: r2utf8-string resource-dir
	resources: glib/resources_enumerate_children (addr-of s-resource-dir) 0 0

	if zero? resources [
		leave
	]

	sizeof-pointer: length? make struct! [p [pointer]]

	i: 0
	res: make struct! compose/deep [
		[raw-memory: (resources + (i * sizeof-pointer))]
		ptr [pointer]
	]

	while [not zero? res/ptr] [
		res-name: utf82r-string res/ptr
		resource-name: rejoin [resource-dir "/" res-name]

		debug ["resource-name:" resource-name]
		s-resource-name: r2utf8-string resource-name
		widget: gtk/image_new_from_resource (addr-of s-resource-name)

		if all [gtk/image_get_pixbuf widget
				gtk/image_get_animation widget][
			glib/object_ref_sink widget
			gtk/widget_destroy widget

			bytes: glib/resources_lookup_data (addr-of s-resource-name) 0 0
			either glib/utf8_validate (glib/bytes_get_data bytes 0) (glib/bytes_get_size bytes) 0 [
				; Looks like it parses as text. Dump it into a textview then!

				set [widget textview] create-text false
				buffer: gtk/text_buffer_new 0
				gtk/text_buffer_set_text buffer (glib/bytes_get_data bytes 0) (glib/bytes_get_size bytes)
				gtk/text_view_set_buffer textview buffer
			][
				s-format: r2utf8-string "Don't know how to display resources '%s'\n"
				glib/log reduce [ 0 glib/GLogLevelFlags/G_LOG_LEVEL_WARNING
					(addr-of s-format)
					(addr-of s-resource-name) [pointer]]
				widget: 0
			]

			glib/bytes_unref bytes
		]

		gtk/widget_show_all widget

		label: gtk/label_new res/ptr

		gtk/widget_show label

		gtk/notebook_append_page notebook widget label
		s-tab-expand: r2utf8-string "tab-expand"
		gtk/container_child_set
			notebook widget
			(addr-of s-tab-expand)
			1 [int32] 0 [pointer]
        |

		i: ++ 1
		res: make struct! compose/deep [
			[raw-memory: (resources + (i * sizeof-pointer))]
			ptr [pointer]
		]
	]
]

load-file: procedure [
	demoname [any-string!]
	filename [any-string!]
    <with>
        current-file
        source-textview
        info-textview
][
	if current-file = filename [leave]

	current-file: filename
	remove-data-tabs
	add-data-tab demoname

	info-buffer: gtk/text_buffer_new 0
	source-buffer: gtk/text_buffer_new 0

	error: make struct! compose [
		data [pointer]
	]
	resource-file: join-of "/sources/" filename
	s-resource-file: r2utf8-string resource-file
	bytes: glib/resources_lookup_data (addr-of s-resource-file) 0 (addr-of error)
	if zero? bytes [
		error-val: make-similar-struct glib/GError compose/deep [
			[raw-memory: (error/data)]
		]
		s-format: r2utf8-string "Cannot open source for %s: %s\n"
		s-filename: r2utf8-string filename
		glib/log reduce [ 0 glib/GLogLevelFlags/G_LOG_LEVEL_CRITICAL
			(addr-of s-format)
			(addr-of s-filename) [pointer]
			error-val/message [pointer]
		]
		leave
	]

	data-size: glib/bytes_get_size bytes
	bytes-reb: make struct! compose/deep [
		data: [uint8 [(data-size)]] (glib/bytes_get_data bytes 0)
	]

	glib/bytes_unref bytes

	bytes-bin: values-of bytes-reb

	source: load/header bytes-bin
	header: first source
	;debug ["source:" mold source]
	
	gtk/text_buffer_set_text source-buffer bytes-bin data-size
	;fontify source-buffer
	gtk/text_view_set_buffer source-textview source-buffer
	glib/object_unref source-buffer

	s-notes: r2utf8-string header/notes
	gtk/text_buffer_set_text info-buffer (addr-of s-notes) (length? header/notes)
	;fontify source-buffer
	gtk/text_view_set_buffer info-textview info-buffer
	glib/object_unref info-buffer
]

activate: mk-cb [
	app [pointer]
    <with>
        global-mem-pool
        notebook
        info-textview
        source-textview
        treeview
        headerbar
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
		data [pointer]
	]

	append global-mem-pool reduce [
		s-run s-ui-main s-window
		s-notebook s-info-textview s-source-textview
		s-headerbar s-treeview s-row-activated
		s-treeview-selection s-changed
	]

	action-entry: make-similar-struct glib/GActionEntry compose [
		name: (addr-of s-run)
		activate: (addr-of :activate-run)
	]

	win-entries: make struct! compose compose/deep[
		entry: [(glib/GActionEntry) [1]] [(action-entry)]
	]

	builder: gtk/builder_new
	gtk/builder_add_from_resource builder (addr-of s-ui-main) (addr-of error)

	unless zero? error/data [
		error-val: make-similar-struct glib/GError compose/deep [
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

	debug ["original notebook:" notebook]

	load-file demos/1/name demos/1/filename ;FIXME

	populate-model model

	debug ["in active treeview:" to-hex treeview "model:" to-hex model]
	glib/signal_connect treeview addr-of s-row-activated addr-of :row-activated-cb model

	widget: gtk/builder_get_object builder addr-of s-treeview-selection
	glib/signal_connect widget (addr-of s-changed) (addr-of :selection-cb) model

	gtk/widget_show_all window
	glib/object_unref builder
]

init-resource: function [
][
	s-resource: r2utf8-string "demo.gresource"
	error: make struct! compose [
		data [pointer]
	]
	resource: glib/resource_load addr-of s-resource addr-of error
	unless zero? error/data [
		error-val: make-similar-struct glib/GError compose/deep [
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

main: function [
	argc [integer!]
	argv [struct!]
    <with>
    	activate
][
	init-resource

	s-about: r2utf8-string "about"
	s-quit: r2utf8-string "quit"

	about-entry: make-similar-struct glib/GActionEntry compose [
		name: (addr-of s-about)
		activate: (addr-of :activate-about)
	]

	debug ["addr-of s-about:" addr-of s-about]
	debug ["about-entry/name:" about-entry/name]
	;debug ["s-about:" utf82r-string about-entry/name]

	quit-entry: make-similar-struct glib/GActionEntry compose [
		name: (addr-of s-quit)
		activate: (addr-of :activate-quit)
	]

	app-entries: make struct! compose/deep/only [
		entries: [(glib/GActionEntry) [2]] (reduce [about-entry quit-entry])
	]

	debug ["length of app-entries in bytes:" length? app-entries]
	debug ["length of GActionEntry in bytes:" length? glib/GActionEntry]
	app-domain: to binary! "org.gtk.Demo"
	app: gtk/application_new
		app-domain
		glib/GApplicationFlags/G_APPLICATION_NON_UNIQUE

    dump app

	glib/action_map_add_action_entries
		app
		addr-of app-entries
		((length? app-entries) / (length? glib/GActionEntry))
		app
	
	debug ["connect startup"]
	s-startup: r2utf8-string "startup"
	glib/signal_connect app (addr-of s-startup) addr-of :startup 0

	debug ["connect activate"]
	s-activate: r2utf8-string "activate"
	glib/signal_connect app addr-of s-activate addr-of :activate 0

	debug ["calling application_run"]
	app-val: make-similar-struct glib/GApplication compose/deep [
		[raw-memory: (app)]
	]
	glib/application_run app argc addr-of argv
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
	data: [pointer [(1 + argc)]] (argv-ptr)
]

;dump-memory %/mnt/work/dump2dot.git/test/gtk-demo.txt
main argc argv
;main 0 0
