REBOL []

;recycle/torture
function-filter: func [
	f [object!]
][
	all [
		found? find/match f/name "tcc_"
		f/availability = clang/enum clang/CXAvailabilityKind 'CXAvailability_Available
	]
]

function-ns: func [
	f [object!]
][
	either found? find/match f/name "tcc__" [
		"tcc_"
	][
		""
	]
]

struct-filter: func [
	s [object!]
][
	true
]

enum-filter: func [
	e [object!]
][
	true
]

OUTPUT: %libtcc-binding.reb

do %../lib/c2r3.reb

argv-data: compose [
	(r2utf8-string "c2r3.reb")
	(r2utf8-string "/usr/include/libtcc.h")
]

argc: length? argv-data

argv-ptr: copy []
foreach v argv-data [append argv-ptr addr-of v]
argv: make struct! compose/deep/only [
	data: [pointer [(argc)]] (argv-ptr)
]

compile argc addr-of argv

write OUTPUT {REBOL [
	comment: "Generated by c2r3.reb, DO NOT EDIT"
]
make object! [
}
write-output OUTPUT ["libtcc" %libtcc.so]
write/append OUTPUT {
	compile: function [
		spec [block!]
		source [any-string!]
	][
		spec-obj: make object! [
			sysincludes: copy []
			includes: copy []
			defines: copy []
			libraries: copy []
			library-paths: copy []
		]

		program: make object! [
			state: 0
			m-buf: none ;memory to hold the program
		]

		debug-rule: [
			'debug set value logic! (spec-obj/debug: value)
		]

		include-rule: [
			'include [
				set path file! (append spec-obj/includes path)
				| set paths block! (
					foreach p paths [
						append spec-obj/includes p
					]
				)
			]
		]

		sysinclude-rule: [
			'sysinclude [
				set path file! (append spec-obj/sysincludes path)
				| set paths block! (
					foreach p paths [
						append spec-obj/sysincludes p
					]
				)
			]
		]

		define-rule: [
			'define set defines block! (
				unless block? defines/d [
					defines: reduce [defines]
				]
				foreach d defines [
					append spec-obj/defines make object! [
						name: d/1
						value: pick d 2
						define: true
					]
				]
			)
		]

		undef-rule: [
			'undef set undefs block! (
				unless block? undefs/d [
					undefs: reduce [undefs]
				]
				foreach d undefs [
					append spec-obj/defines make object! [
						name: d/1
						value: pick d 2
						define: false
					]
				]
			)
		]

		library-rule: [
			'library [
				set lib any-string! (append spec-obj/libraries lib)
				| set libs block! (
					foreach lib libs [
						append spec-obj/libraries lib
					]
				)
			]
		]

		library-path-rule: [
			'library-path [
				set lib any-string! (append spec-obj/library-paths lib)
				| set libs block! (
					foreach lib libs [
						append spec-obj/library-paths lib
					]
				)
			]
		]

		unless parse reduce spec [
			any [
				include-rule
				| sysinclude-rule
				| define-rule
				| undef-rule
				| library-rule
				| library-path-rule
				;| debug-rule
			]
		][
			do make error! "invalid spec"
		]

		;print ["spec-obj:" mold spec-obj]

		program/state: tcc_new

		foreach def spec-obj/defines [
			either def/define [
				n: join to binary! def/name #{00}
				v: join to binary! mold def/value #{00}
				tcc_define_symbol program/state n v
			][;undef
				n: join to binary! def/name #{00}
				tcc_undefine_symbol program/state n
			]
		]

		foreach inc spec-obj/sysincludes [
			path: join to binary! to string! inc #{00};hold a reference to the string
			tcc_add_sysinclude_path program/state path
		]

		foreach inc spec-obj/includes [
			path: join to binary! to string! inc #{00};hold a reference to the string
			tcc_add_include_path program/state path
		]

		foreach lib spec-obj/libraries [
			path: join to binary! to string! lib #{00};hold a reference to the string
			tcc_add_library program/state path
		]

		foreach lib spec-obj/library-paths [
			path: join to binary! to string! lib #{00};hold a reference to the string
			tcc_add_library_path program/state path
		]

		s: join to binary! source #{00}
		if negative? tcc_compile_string program/state s [
			do make error! "Failed to compile"
		]

		;find out the needed memory size
		m-size: tcc_relocate program/state 0
		;print ["m-size: " m-size]

		program/m-buf: make binary! m-size
		if negative? tcc_relocate program/state program/m-buf [
			do make error! "Failed to relocate"
		]

		program
	]

	destroy: func [
		"Release resources of a compiled program"
		program [object!]
	][
		program/m-buf: none ;release program memory
		tcc_delete program/state
	]

	load-func: function [
		prog [object!] "object returned from compile-c"
		name [any-string!]
		spec [block!] "routine parameter spec"
	][
		name: join to binary! name #{00}
		if zero? ptr: tcc_get_symbol prog/state name [
			do make error! rejoin ["Failed to find symbol " to string! name]
		]

		make routine! reduce [spec ptr]
	]
]
}