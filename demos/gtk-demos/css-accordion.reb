REBOL [
	Title: "CSS Theming/CSS Accordion"
	Notes: "A simple accordion demo written using CSS transitions and multiple backgrounds"
]

css-accordion-window: make struct! compose [
	win [pointer]
]

apply-css-cb: 0

apply-css: procedure [
	widget [integer!]
	provider [integer!]
    <with>
        apply-css-cb
][
	maxuint: to integer! #FFFFFFFF
	gtk/style_context_add_provider (gtk/widget_get_style_context widget) provider maxuint
	assert [function? :apply-css-cb]
	if glib/type-check-instance-type widget gtk/container_get_type [
		gtk/container_forall widget (addr-of :apply-css-cb) provider
	]
]

apply-css-cb: wrap-callback :apply-css [
	widget [pointer]
	provider [pointer]
]

do-css-accordion: function [
	do-widget [integer!]
    <with>
        css-accordion-window
][
	if zero? css-accordion-window/win [
		window: css-accordion-window/win: gtk/window_new gtk/GtkWindowType/GTK_WINDOW_TOPLEVEL
		gtk/window_set_transient_for window do-widget
		gtk/window_set_default_size window 600 300
		s-destroy: join-of to binary! "destroy" #{00}
		glib/signal_connect window s-destroy (addr-of :gtk/widget_destroyed) (addr-of css-accordion-window)

		container: gtk/box_new gtk/GtkOrientation/GTK_ORIENTATION_HORIZONTAL 0
		gtk/widget_set_halign container gtk/GtkAlign/GTK_ALIGN_CENTER
		gtk/widget_set_valign container gtk/GtkAlign/GTK_ALIGN_CENTER
		gtk/container_add window container

		s-this: join-of to binary! "This" #{00}
		child: gtk/button_new_with_label s-this
		gtk/container_add container child

		s-is: join-of to binary! "Is" #{00}
		child: gtk/button_new_with_label s-is
		gtk/container_add container child

		s-a: join-of to binary! "A" #{00}
		child: gtk/button_new_with_label s-a
		gtk/container_add container child

		s-CSS: join-of to binary! "CSS" #{00}
		child: gtk/button_new_with_label s-CSS
		gtk/container_add container child

		s-Accordion: join-of to binary! "Accordion" #{00}
		child: gtk/button_new_with_label s-Accordion
		gtk/container_add container child

		s-smile: join-of to binary! ":-)" #{00}
		child: gtk/button_new_with_label s-smile
		gtk/container_add container child

		provider: gtk/css_provider_new

		s-css-file: join-of to binary! "/css_accordion/css_accordion.css" #{00}
		bytes: glib/resources_lookup_data s-css-file 0 0
		debug ["bytes:" bytes]
		data-size: make struct! [i [int64]]
		data: glib/bytes_get_data bytes (addr-of data-size)

		debug ["data-size:" data-size/i]
		gtk/css_provider_load_from_data provider data data-size/i 0
		glib/bytes_unref bytes

		apply-css window provider
	]

	either zero? gtk/widget_get_visible css-accordion-window/win [
		gtk/widget_show_all css-accordion-window/win
	][
		gtk/widget_destroy css-accordion-window/win
		css-accordion-window/win: 0
	]
	css-accordion-window/win
]
