REBOL []

clang: do %clang.reb
;do %config.reb
;do %config-all.reb

libc: make library! %libc.so.6

LP64?: true

strlen: make routine! compose [
	[
		s [pointer]
		return: [uint64]
	]
	(libc) "strlen"
]

stringfy: func [
	ptr [integer!]
	/local len s
] [
	len: strlen ptr
	s: make struct! [
		uint8 [len] s: ptr
	]
	to string! values-of s
]

c-struct: make object! [
	name: none
	global: true
	fields: copy []
	aliases: copy []
]

global-structs: make object! [
	hash: make map! 16
	n-structs: 0
	structs: make block! 16
]

c-field: make object! [
	name: none
	offset:
	bits:
	size:
	align: 0
	type: 0
	dimension: 1
	typedef: none
	is-struct?: false
]

c-arg-class: make object! [
	name:
	type: none
	is-struct?: false ;is c struct
]

c-func-class: make object! [
	name: none
	args: copy []
	variadic?: false
	return-type: none
	return-struct?: false
	abi: none
]

global-functions: make block! 16

c-2-reb-type: func [
	type [struct!]
	orig-type [struct! none!]
	/local ret type-name type-name-reb struct?
][
	ret: switch/default type/kind compose [
		(clang/enum clang/CXTypeKinds 'CXType_Void) [
			"void"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Char_U) [ ; FIXME unicode char?
			"uint32"
		]
		(clang/enum clang/CXTypeKinds 'CXType_UChar) [
			"uint8"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Char16) [
			"int16"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Char32) [
			"int32"
		]
		(clang/enum clang/CXTypeKinds 'CXType_UShort) [
			"uint16"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Uint) [
			"uint32"
		]
		(clang/enum clang/CXTypeKinds 'CXType_ULong) [
			either LP64? ["uint64"]["uint32"]
		]
		(clang/enum clang/CXTypeKinds 'CXType_ULongLong) [
			"uint64"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Char_S) [
			"int8"
		]
		(clang/enum clang/CXTypeKinds 'CXType_SChar) [
			"int8"
		]
		(clang/enum clang/CXTypeKinds 'CXType_WChar) [
			"int16"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Short) [
			"int16"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Int) [
			"int32"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Long) [
			either LP64? ["int64"]["int32"]
		]
		(clang/enum clang/CXTypeKinds 'CXType_LongLong) [
			"int64"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Float) [
			"float"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Double) [
			"double"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Pointer) [
			"pointer"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Enum) [
			"int32"
		]
		(clang/enum clang/CXTypeKinds 'CXType_ConstantArray) [
			"pointer"
		]
		(clang/enum clang/CXTypeKinds 'CXType_Record) [
			struct?: true
			either none? orig-type [
				type-name: clang/getTypeSpelling type
			][
				type-name: clang/getTypeSpelling orig-type
			]
			type-name-reb: stringfy clang/getCString clang/getTypeSpelling type
			if "struct " = copy/part type-name-reb length? "struct " [
				type-name-reb: skip type-name-reb length? "struct "
			]
			clang/disposeString type-name
			either empty? type-name-reb [
				rejoin ["(FIXME: empty type-name)"]
			][
				type-name-reb
			]
		]
		;CXType_UInt128  12
		;CXType_Int128  20
		;CXType_LongDouble  23
	][
		type-name: clang/getTypeSpelling type
		type-name-reb: stringfy clang/getCString type-name
		clang/disposeString type-name
		either "enum " = copy/part type-name-reb 5 [
			"int32"
		][
			rejoin ["FIXME:" type/kind ", " type-name-reb]
		]
	]
	reduce [ret to logic! struct?]
]

mk-cb: func [
	args [block!]
	body [block!]
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

	;print ["args:" mold args]

	tmp-func: function r-args body

	;print ["tmp-func:" mold :tmp-func]
	make callback! compose/deep [[(args)] :tmp-func]
]

print-diagnostics: function [
	translationUnit
][
	n: clang/getNumDiagnostics translationUnit
	print ["There is" n "diagnostics"]
	i: 0
	while [i < n] [
		diag: clang/getDiagnostic translationUnit i
		s: clang/formatDiagnostic diag 0
		print [stringfy clang/getCString s]
		clang/disposeDiagnostic diag

		++ i
	]
]

c-2-rebol-arg-type: func [
	type [struct!]
	/local orig-type type-name type-name-reb
][
	; typedef
	while [type/kind = clang/enum clang/CXTypeKinds 'CXType_Typedef][
		orig-type: type
		type: clang/getCanonicalType type
	]

	c-2-reb-type type orig-type
]

write-a-rebol-arg: func [
	c-arg 	[object!]
	idx		[integer!] "the arg index"
	indent [integer!]
	/local ret ind
][
	ind: copy ""
	insert/dup ind "^-" indent
	rejoin [
		ind
		either empty? c-arg/name [join "arg" 1 + idx][c-arg/name]
		" ["
		either c-arg/is-struct? [
			rejoin ["(" c-arg/type ")"]
		][
			c-arg/type
		]
		"]^/"
	]
]

write-a-rebol-func-calling-conv: func [
	abi [integer!]
][
	;CXCallingConv_Default = 0,
	;CXCallingConv_C = 1,
	;CXCallingConv_X86StdCall = 2,
	;CXCallingConv_X86FastCall = 3,
	;CXCallingConv_X86ThisCall = 4,
	;CXCallingConv_X86Pascal = 5,
	;CXCallingConv_AAPCS = 6,
	;CXCallingConv_AAPCS_VFP = 7,
	;CXCallingConv_PnaclCall = 8,
	;CXCallingConv_IntelOclBicc = 9,
	;CXCallingConv_X86_64Win64 = 10,
	;CXCallingConv_X86_64SysV = 11,
	any compose [
		pick [
			"default"	;0
			"default"	;1
			"stdcall"	;2
			"fastcall"	;3
			"thiscall"	;4
			"stdcall"	;Pascal 5
			"FIXME"	;AAPCS 6
			"FIXME" ;"aapcs-vfp"	;7
			"FIXME" ;"pnaclcall"	;8
			"FIXME" ;"inteloclbicc"	;9
			"win64"	;10
			"sysv"	;11
		] (abi + 1)
		"FIXME"
	]
]

write-a-rebol-func: func [
	c-func 	[object!]
	lib		[any-string!]
	ns		[function! none!]
	indent [integer!]
	/win32
	/local ret i extern-name
][
	extern-name: either all [
		win32
		1 = c-func/abi
	][
		join "_" c-func/name
	][
		c-func/name
	]

	ret: copy ""
	insert/dup ret "^-" indent
	append ret rejoin [
		either none? :ns [
			c-func/name
		][
			skip c-func/name (length? ns c-func/name)
		]
		": make routine! compose/deep [[^/"
	]

	i: 0
	foreach arg c-func/args [
		append ret write-a-rebol-arg arg i (1 + indent)
		++ i
	]

	if c-func/variadic? [
		loop 1 + indent [append ret "^-"]
		append ret "...^/"
	]

	loop 1 + indent [append ret "^-"]
	append ret rejoin ["return: [" write-a-c-type reduce [c-func/return-type c-func/return-struct?] "]^/"]

	loop 1 + indent [append ret "^-"]
	append ret rejoin [
		"abi: " write-a-rebol-func-calling-conv c-func/abi "^/"
	]

	loop indent [append ret "^-"]
	append ret rejoin ["] (" to string! lib ") ^"" extern-name "^"]^/"]
]

write-a-c-type: func [
	"Add parenthesis to the type name if it's a struct"
	block [block!] "return value from c-2-reb-type"
][
	either second block [
		rejoin ["(" first block ")"]
	][
		first block
	]
]

write-a-rebol-field: func [
	c-field [object!]
	'offset [word!] "the current offset in the struct, in bits"
	idx		[integer!] "the field index"
	indent [integer!]
	/local ret ind
][
	ind: copy ""
	insert/dup ind "^-" indent
	ret: copy ""
	case [
		(get offset) < c-field/offset [
			;padding
			;print ["padding is needed for field: " c-field/name "offset:" mold get offset "c-field/offset:" mold c-field/offset]
			append ret rejoin [ind "uint8 [" (c-field/offset - (get offset)) / 8 "] padding" idx "^/"]
			set offset c-field/offset
		]
		(get offset) > c-field/offset [
			append ret rejoin [ind ";" c-field/name ", merged with the previous field^/"]
			return ret
		]
	]

	append ret rejoin [
		either none? c-field/typedef [
			;print ["field" mold c-field]
			case [
				string? c-field/type [
					rejoin [ind write-a-c-type reduce [c-field/type c-field/is-struct?]]
				]
				struct? c-field/type [
					rejoin [ind write-a-c-type (c-2-reb-type c-field/type none)]
				]
				object? c-field/type [
					either c-field/type/global [
						rejoin ["(" c-field/type/name ")"]
					][
						write-a-rebol-struct c-field/type indent
					]
				]
				'else [
					rejoin [ind "WRONG " c-field/type]
					print ["WRONG" c-field/type]
				]
			]
		][
			rejoin [ind "("	c-field/typedef ")"]
		]
		" "
		either c-field/dimension > 1 [
			rejoin ["[" c-field/dimension "] "]
		][
			""
		]
		c-field/name
		"^/"
	]
	set offset (get offset) + (c-field/size * 8)
	;print ["offset:" get offset]

	ret
]

write-a-rebol-struct: func [
	c-struct [object!]
	indent [integer!]
	/local ret a offset idx anonymous?
][
	ret: copy ""
	insert/dup ret "^-" indent

	either none? c-struct/name [
		anonymous?: true
	][
		anonymous?: false
		append ret join c-struct/name ": "
		foreach a c-struct/aliases [
			append ret join a ": "
		]
		append ret "make "
	]
	append ret rejoin ["struct! " either anonymous? [""]["compose/deep "] "[^/"]
	offset: 0
	idx: 0
	foreach f c-struct/fields [
		append ret write-a-rebol-field f offset idx (1 + indent)
		++ idx
	]
	loop indent [append ret "^-"]
	append ret "]"
	ret
]

struct-visitor-fields: mk-cb compose/deep [
	cursor [(clang/CXCursor)]
	parent [(clang/CXCursor)]
	client-data [pointer]
	return: [(clang/CXChildVisitResult)]
][
	;print ["client-data:" to-hex client-data]
	n: make struct! compose/deep [
		[raw-memory: (client-data)]
		rebval v
	]
	v: n/v ;c-struct
	field-name: clang/getCursorSpelling cursor
	field-name-reb: stringfy clang/getCString field-name
	;print ["field-name:" field-name-reb]
    kind: clang/getCursorKind cursor
    if kind = target-kind: clang/enum clang/CXCursorKinds 'CXCursor_FieldDecl [
		type: clang/getCursorType cursor
		if type/kind = clang/enum clang/CXTypeKinds 'CXType_Typedef [
			orig-type: type
			type: clang/getCanonicalType type
		]
		field: make c-field reduce/no-set [
			name: field-name-reb
			offset: clang/Type_getOffsetOf clang/getCursorType parent clang/getCString field-name
			size: clang/Type_getSizeOf type
			align: clang/Type_getAlignOf type
			type: type
			bits: clang/getFieldDeclBitWidth cursor
		]
		dim: 1
		while [type/kind = clang/enum clang/CXTypeKinds 'CXType_ConstantArray][
			dim: dim * clang/getArraySize type
			type: clang/getArrayElementType type
			if type/kind = clang/enum clang/CXTypeKinds 'CXType_Typedef [
				orig-type: type
				type: clang/getCanonicalType type
			]
		]

		; type could be catgorized as below:
		; 1. a typedef'ed struct
		; 2. a nested struct
		; 3. other atomic type
		;print ["type/kind:" type/kind]
		either any [
			type/kind = clang/enum clang/CXTypeKinds 'CXType_Unexposed
			type/kind = clang/enum clang/CXTypeKinds 'CXType_Record
		][
			decl-cursor: clang/getTypeDeclaration type
			decl-cursor-kind: clang/getCursorKind decl-cursor
			decl-cursor-name: clang/getCursorSpelling decl-cursor
			;print ["decl-cursor-name:" stringfy clang/getCString decl-cursor-name]
			clang/disposeString decl-cursor-name
			;print ["decl-cursor-kind:" decl-cursor-kind]

			switch/default decl-cursor-kind compose [
				(clang/enum clang/CXCursorKinds 'CXCursor_EnumDecl) [
					field/type: "int32"
				]
				(clang/enum clang/CXCursorKinds 'CXCursor_StructDecl) [
					semantic-parent: clang/getCursorSemanticParent decl-cursor
					semantic-parent-kind: clang/getCursorKind semantic-parent
					semantic-parent-name: clang/getCursorSpelling semantic-parent
					;print ["parent-name:" stringfy clang/getCString semantic-parent-name]
					clang/disposeString semantic-parent-name

					lexical-parent: clang/getCursorLexicalParent decl-cursor
					lexical-parent-kind: clang/getCursorKind lexical-parent
					lexical-parent-name: clang/getCursorSpelling lexical-parent
					;print ["lexical parent-name:" stringfy clang/getCString lexical-parent-name]
					clang/disposeString lexical-parent-name

					nested-struct: make struct! compose [
						rebval v: (make c-struct [
							global: lexical-parent-kind = clang/enum clang/CXCursorKinds 'CXCursor_TranslationUnit]
						)
					]
					clang/visitChildren decl-cursor addr-of struct-visitor-fields addr-of nested-struct
					field/type: nested-struct/v
					field/is-struct?: true
					unless any [
						none? orig-type
						orig-type/kind != clang/enum clang/CXTypeKinds 'CXType_Typedef
					][
						orig-type-name: clang/getTypeSpelling orig-type
						orig-type-name-reb: stringfy clang/getCString orig-type-name
						unless empty? orig-type-name-reb [
							field/typedef: orig-type-name-reb
						]
						clang/disposeString orig-type-name
					]
				]
				'else [
					t: c-2-reb-type type orig-type
					field/type: first t
					field/is-struct?: second t
				]
			][
				print ["Unexpected cursor-kind" decl-cursor-kind ", expecting structdecl"]
				return clang/enum clang/CXChildVisitResults 'CXChildVisit_Continue
			]
		][
			t: c-2-reb-type type orig-type
			field/type: first t
			field/is-struct?: second t
		]
		field/dimension: dim
		;write/append OUTPUT rejoin [c-2-reb-type elem-type " [" clang/getNumElements type "] " field-name-reb "^/"]
		either none? v/fields [
			v/fields: reduce [field]
		][
			append v/fields field
		]
		clang/disposeString field-name
		return clang/enum clang/CXChildVisitResults 'CXChildVisit_Continue
	]
	clang/enum clang/CXChildVisitResults 'CXChildVisit_Continue
]

cursor-visitor: mk-cb compose/deep [
	cursor [(clang/CXCursor)]
	parent [(clang/CXCursor)]
	client-data [pointer]
	return: [(clang/CXChildVisitResult)]
][
	;print ["cursor-visitor"]
	;print ["cursor:" mold cursor]
	kind: clang/getCursorKind cursor
	case compose [
		(kind = clang/enum clang/CXCursorKinds 'CXCursor_FunctionDecl) [
			name: clang/getCursorSpelling cursor
			func-name-reb: stringfy clang/getCString name
			clang/disposeString name

			unless function-filter func-name-reb [
				return clang/enum clang/CXChildVisitResults 'CXChildVisit_Continue
			]
			func-type: clang/getCursorType cursor
			rtype: clang/getResultType func-type

			rtype-name: clang/getTypeSpelling rtype
			rtype-name-reb: stringfy clang/getCString rtype-name
			clang/disposeString rtype-name
			rtype: c-2-rebol-arg-type rtype
			;print ["rtype:" rtype-name-reb]
			;print ["rtype:" mold rtype]

			c-func: make c-func-class reduce/no-set [
				name: func-name-reb
				return-type: first rtype
				return-struct?: second rtype
				variadic?: not zero? clang/isFunctionTypeVariadic func-type
				abi: clang/getFunctionTypeCallingConv func-type
			]
			n: clang/Cursor_getNumArguments cursor
			;print ["n:" n]
			i: 0
			while [i < n] [
				arg: clang/Cursor_getArgument cursor i
				arg-name: clang/getCursorSpelling arg
				;print ["type" mold type]
				arg-type: c-2-rebol-arg-type clang/getCursorType arg
				c-arg: make c-arg-class [
					name: stringfy clang/getCString arg-name
					type: first arg-type
					is-struct?: second arg-type
				]
				append c-func/args c-arg
				;type-name: clang/getTypeSpelling c-arg/type
				;print rejoin ["parameter:" stringfy clang/getCString arg-name ", type:" stringfy clang/getCString type-name "^/" mold c-arg/type "^/"]
				;clang/disposeString type-name
				clang/disposeString arg-name

				++ i
			]
			;print ["checking for variadic arguments"]
			append global-functions c-func
			return clang/enum clang/CXChildVisitResults 'CXChildVisit_Continue
		]
		(kind = clang/enum clang/CXCursorKinds 'CXCursor_StructDecl) [
			struct-name: clang/getCursorSpelling cursor
			struct-name-reb: stringfy clang/getCString struct-name
			;print ["struct-name:" struct-name-reb]

			parent-kind: clang/getCursorKind parent
			;print ["parent-kind:" parent-kind]
			if parent-kind = target-kind: clang/enum clang/CXCursorKinds 'CXCursor_TypedefDecl [
				typedef-name: clang/getCursorSpelling parent
				typedef-name-reb: stringfy clang/getCString typedef-name
				;print ["typedef-name-reb:" typedef-name-reb]
				clang/disposeString typedef-name
				either empty? struct-name-reb [
					struct-name-reb: typedef-name-reb
					struct-alias: none
				][
					struct-alias: typedef-name-reb
				]
			]
			if empty? struct-name-reb [
				struct-name-reb: none
			]
			clang/disposeString struct-name
			type: clang/getCursorType cursor

			n: make struct! compose [
				rebval v: (make c-struct [name: struct-name-reb])
			]
			unless empty? struct-alias [
				append n/v/aliases struct-alias
			]
			clang/visitChildren cursor addr-of struct-visitor-fields addr-of n
			;print ["found a struct:" mold n/v]
			unless any [none? n/v/name empty? n/v/name][
				aliases: join reduce [n/v/name] n/v/aliases
				;print ["aliases" mold aliases]
				idx: none
				foreach a aliases [
					unless none? idx: global-structs/hash/(a) [break]
				]
				either none? idx [; new struct
					global-structs/n-structs: global-structs/n-structs + 1
					append global-structs/structs n/v
					foreach a aliases [
						append global-structs/hash reduce [a global-structs/n-structs]
					]
				][
					foreach a aliases [
						if none? global-structs/hash/(a) [
							append global-structs/hash reduce [a idx]
						]
						s: global-structs/structs/(idx)
						unless any [
							a = s/name
							found? find s/aliases a
						][
							append s/aliases a
						]
					]
				]
			]
			return clang/enum clang/CXChildVisitResults 'CXChildVisit_Continue
		]
		'else [
			;name: clang/getCursorSpelling cursor
			;print ["cursor name: " stringfy clang/getCString name "kind: " kind]
			return clang/enum clang/CXChildVisitResults 'CXChildVisit_Recurse
		]
		;print ["check for next cursor"]
		;clang/visitChildren cursor addr-of function-visitor 0
	]
]

compile: function [
	argc [integer!]
	argv [integer!]
][
	index: clang/createIndex 0 0
	if zero? index [
		print ["error creating index"]
		quit
	]

	translationUnit: clang/parseTranslationUnit index 0
			argv argc ;argv, argc
			0 0 0

	if zero? translationUnit [
		print ["error creating translationUnit"]
		quit
	]

	print-diagnostics translationUnit

	root-cursor: clang/getTranslationUnitCursor translationUnit

	clang/visitChildren root-cursor addr-of cursor-visitor 0
	clang/disposeTranslationUnit translationUnit
	clang/disposeIndex index
]

write-output: func [
	dest [file!]
	/local written-structs s a func-to-expose f write-a-complete-struct
][
	write dest ""

	written-structs: make map! 32
	func-to-expose: make block! 16

	export-struct: func [
		s [object!]
	][
	  	unless found? select written-structs s/name [
			append written-structs reduce [s/name true]
			foreach a s/aliases [
				append written-structs reduce [a true]
			]
		]
	]

	foreach s global-structs/structs [
		unless zero? length? s/fields [ ;ex: typedef struct a *pa;
			either function? get 'struct-filter [
				if struct-filter s/name [
					write/append dest rejoin [write-a-rebol-struct s 1 "^/"]
					export-struct s
				]
			][
				write/append dest rejoin [write-a-rebol-struct s 1 "^/"]
				export-struct s
			]
		]
	]

	either function? :function-filter [
		foreach f global-functions [
			if function-filter f/name [
				append func-to-expose f
			]
		]
	][
		func-to-expose: global-functions	
	]
	
	write-a-complete-struct: func [
		s [object!]
		/local f ns
	][
		;print ["writing a complete struct:" mold s]
		foreach f s/fields [
			if all [
				f/is-struct?
				object? f/type
				f/type/global
				not found? select written-structs any [f/type/name f/typedef]
			][
				;print ["trying to find struct for:" mold f]
				ns: pick global-structs/structs (select global-structs/hash any [f/type/name f/typedef])
				write-a-complete-struct ns
			]
		]
		write/append dest rejoin [write-a-rebol-struct s 1 "^/"]
		export-struct s
	]

	; write all structs required by func
	foreach f func-to-expose [
		foreach a f/args [
			if all [
				a/is-struct?
				not found? select written-structs a/type
			][
				;write the struct and its dependency
				s: pick global-structs/structs (select global-structs/hash a/type)
				write-a-complete-struct s
			]
		]
		if all [
			f/return-struct?
			not found? select written-structs f/return-type
		][
			s: pick global-structs/structs (select global-structs/hash f/return-type)
			write-a-complete-struct s
		]
	]

	;print ["exported structs:" mold written-structs]

	write/append dest rejoin ["^-clang: make library! %libclang.so^/"]

	foreach f func-to-expose [
		;print ["f:" mold f]
		write/append dest rejoin [write-a-rebol-func f "clang" (get 'function-ns) 1 "^/"]
	]
]

r2utf8-string: function [
	s [any-string!]
][
	bin-arg: to binary! s
	arg: make struct! compose/deep [
		uint8 [(1 + length? bin-arg)] data
	]
	change arg join bin-arg #{00}
	addr-of arg
]
