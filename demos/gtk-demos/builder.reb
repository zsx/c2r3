REBOL [
	Title: "Builder"
	Notes: "Demonstrates an interface loaded from a XML description"
]

builder-window: 0
builder-builder: 0

quit-activate: mk-cb [
		action [pointer]
        <with>
            builder-window
            builder-builder
][
	debug ["quit-active"]
	s-window1: r2utf8-string "window1"
	window: gtk/builder_get_object builder-builder addr-of s-window1
	gtk/widget_destroy window
	builder-window: 0
	unless zero? builder-builder [
		glib/object_unref builder-builder
	]
]

about-activate: mk-cb [
		action [pointer]
][
	debug ["about-active"]
	s-aboutdialog1: r2utf8-string "aboutdialog1"
	about-dlg: gtk/builder_get_object builder-builder addr-of s-aboutdialog1
	gtk/dialog_run about-dlg
	gtk/widget_hide about-dlg
]

help-activate: mk-cb [
		action [pointer]
][
	print ["Help not available"]
]

do-builder: function [
	do_widget [integer!]
    <with>
        builder-window
        builder-builder
][
	s-demo: r2utf8-string "/builder/demo.ui"
	s-window1: r2utf8-string "window1"

	append global-mem-pool s-demo

	error: make struct! compose [
		data [pointer]
	]

	if zero? builder-window [
		debug ["building new window"]
		builder-builder: gtk/builder_new
		gtk/builder_add_from_resource builder-builder (addr-of s-demo) (addr-of error)

		unless zero? error/data [
			error-val: make glib/GError compose/deep [
				[raw-memory: (error/data)]
			]
			s-format: r2utf8-string "%s"
			glib/log reduce [ 0 glib/GLogLevelFlags/G_LOG_LEVEL_CRITICAL
				addr-of s-format
				error-val/message [pointer]
			]
			debug ["exiting"]
			exit
		]

		s-about-activate: r2utf8-string "about_activate"
		s-help-activate: r2utf8-string "help_activate"
		s-quit-activate: r2utf8-string "quit_activate"
		gtk/builder_add_callback_symbols reduce [
			builder-builder
			(addr-of s-about-activate)
			(addr-of about-activate)
			(addr-of s-help-activate) 	[pointer]
			(addr-of help-activate)		[pointer]
			(addr-of s-quit-activate) 	[pointer]
			(addr-of quit-activate)		[pointer]
			0	[pointer]
		]

		gtk/builder_connect_signals builder-builder 0

		builder-window: gtk/builder_get_object builder-builder addr-of s-window1
		gtk/window_set_screen builder-window gtk/widget_get_screen do_widget
		window-addr: make struct! compose [
			win: [pointer] (builder-window)
		]

		s-destroy: r2utf8-string "destroy"
		;glib/signal_connect builder-window (addr-of s-destroy)
		;	(addr-of :gtk/widget_destroyed) (addr-of window-addr)
		glib/signal_connect builder-window (addr-of s-destroy)
			(addr-of quit-activate) (addr-of window-addr)

		s-toolbar1: r2utf8-string "toolbar1"
		toolbar: gtk/builder_get_object builder-builder (addr-of s-toolbar1)

		s-primary-toolbar: r2utf8-string "primary-toolbar"
		gtk/style_context_add_class gtk/widget_get_style_context toolbar (addr-of s-primary-toolbar)
	]

	either zero? gtk/widget_get_visible builder-window [
		gtk/widget_show_all builder-window
	][
		gtk/widget_destroyed builder-window
		builder-window: 0
	]

	builder-window
]
