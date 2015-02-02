REBOL [
	Title: "Builder"
	Notes: "Demonstrates an interface loaded from a XML description"
]

builder-window: 0

quit-active: mk-cb [
		action [pointer]
][
]

do-builder: function/extern [
	do_widget [integer!]
][
	s-demo: r2utf8-string "/builder/demo.ui"
	s-window1: r2utf8-string "window1"

	append global-mem-pool s-demo

	error: make struct! compose [
		pointer data
	]

	if zero? builder-window [
		debug ["building new window"]
		builder: gtk/builder_new
		gtk/builder_add_from_resource builder (addr-of s-demo) (addr-of error)

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
		gtk/builder_connect_signals builder 0
		builder-window: gtk/builder_get_object builder addr-of s-window1
		gtk/window_set_screen builder-window gtk/widget_get_screen do_widget
		window-addr: make struct! compose [
			pointer win: (builder-window)
		]

		s-destroy: r2utf8-string "destroy"
		glib/signal_connect builder-window (addr-of s-destroy)
			(addr-of :gtk/widget_destroyed) (addr-of window-addr)

		s-toolbar1: r2utf8-string "toolbar1"
		toolbar: gtk/builder_get_object builder (addr-of s-toolbar1)

		s-primary-toolbar: r2utf8-string "primary-toolbar"
		gtk/style_context_add_class gtk/widget_get_style_context toolbar (addr-of s-primary-toolbar)
	]

	either gtk/widget_get_visible builder-window [
		gtk/widget_show_all builder-window
	][
		gtk/widget_destroyed builder-window
		builder-window: 0
	]

	return builder-window
][
	builder-window
]
