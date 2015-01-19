REBOL []

function-filter: func [
	f
][
	found? find/match f/name "clang_"
]

function-ns: func [
	f
][
	either found? find/match f/name "clang_" [
		"clang_"
	][
		""
	]
]

struct-filter: func [
	s
][
	;found? find/match name "CX"
	false
]

enum-filter: func [
	e [object!]
][
	all [
		not empty? e/name
		not empty? e/key-value
	]
]

OUTPUT: %clang-tmp.reb

do %../lib/c2r3.reb

argv-data: compose [
	(r2utf8-string "c2r3.reb")
	(r2utf8-string "-I/usr/lib/clang/3.5.0/include")
	(r2utf8-string "-fsyntax-only")
	(r2utf8-string "/usr/include/clang-c/Index.h")
]

argc: length? argv-data
argv: addr-of make struct! compose/deep/only [
	pointer [(argc)] data: argv-data
]

compile argc argv

write OUTPUT rejoin [ {REBOL [
	Date: } to string! now/date {
	Note: "Generated by c2r3.reb, DO NOT EDIT"
]

make object! [
	enum: func [
		ser
		item
		/local i
	][
		i: select ser item
		while [word? i] [
			i: select ser i
		]
		i
	]

}
]
write-output OUTPUT "clang" %libclang.so

write/append OUTPUT "]^/"

rename OUTPUT %clang.reb
