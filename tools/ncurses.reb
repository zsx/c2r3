REBOL []

;recycle/torture
function-filter: func [
	f [object!]
][
	all [
		#"_" != first f/name
		"trace" != f/name ;trace is not in the library
		f/availability = clang/enum clang/CXAvailabilityKind 'CXAvailability_Available
	]
]

function-ns: func [
	f [object!]
][
	""
]

struct-filter: func [
	s [object!]
][
	false
]

enum-filter: func [
	e [object!]
][
	false
]

OUTPUT: %ncurses-binding.reb

do %../lib/c2r3.reb

argv-data: compose [
	(r2utf8-string "c2r3.reb")
	(r2utf8-string "-I/usr/lib/clang/3.8.0/include")
	(r2utf8-string "-fsyntax-only")
	(r2utf8-string "-DNCURSES_ENABLE_STDBOOL_H=0") ;r3 has problem handling C99 _Bool
	(r2utf8-string "/usr/include/ncurses.h")
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
write-output OUTPUT ["ncurses" %libncursesw.so]
write/append OUTPUT {
]
}
