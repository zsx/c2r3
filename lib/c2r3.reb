REBOL []

;recycle/torture
ARCH: 'LP32
switch first system/platform [
	Linux [
		switch/default second system/platform [
			libc-x64 [
				clang: do %clang-posix-lp64.reb
				ARCH: 'LP64
			]
		][
			clang: do %clang-posix-lp32.reb
		]
		libc: make library! %libc.so.6
	]
	Windows [
		switch second system/platform [
			win32-x64 [
				clang: do %clang-win32-x64.reb
				ARCH: 'LLP64
			]
			win32-x86 [
				clang: do %clang-win32-x32.reb
			]
		]
		libc: make library! %msvcrt.dll
	]
]

debug: :comment
;debug: :print

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
	s: make struct! compose/deep [
		s: [uint8 [(len)]] ptr
	]
	to string! values-of s
]

c-datatype: make object! [
	file: none
	col: row: 0
]
c-struct: make c-datatype [
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

c-enum-class: make c-datatype [
	name: none
	key-value: copy []
	aliases: copy []
]

global-enums: make block! 16
global-typedefs: make map! 16

c-arg-class: make object! [
	name:
	type: none
	is-struct?: false ;is c struct
]

c-func-class: make c-datatype [
	name: none
	args: copy []
	variadic?: false
	return-type: none
	return-struct?: false
	abi: none
	availability: none
	lib: none
]

global-functions: make object! [
	hash: make map! 16
	funcs: make block! 16
]

c-2-reb-type: func [
	type [struct!]
	orig-type [struct! none!]
	/local size ret type-name type-name-reb struct?
][
	struct?: false
	case [
		found? find reduce [
			clang/CXTypeKind/CXType_Char_S
			clang/CXTypeKind/CXType_SChar
			clang/CXTypeKind/CXType_WChar
			clang/CXTypeKind/CXType_Short
			clang/CXTypeKind/CXType_Int
			clang/CXTypeKind/CXType_Long
			clang/CXTypeKind/CXType_LongLong
			clang/CXTypeKind/CXType_Enum
		] type/kind [
			size: clang/Type_getSizeOf type
			return reduce [join "int" (size * 8) false]
		]
		found? find reduce [
			clang/CXTypeKind/CXType_Char_U
			clang/CXTypeKind/CXType_UChar
			clang/CXTypeKind/CXType_Char16
			clang/CXTypeKind/CXType_Char32
			clang/CXTypeKind/CXType_UShort
			clang/CXTypeKind/CXType_UInt
			clang/CXTypeKind/CXType_ULong
			clang/CXTypeKind/CXType_ULongLong
		] type/kind [
			size: clang/Type_getSizeOf type
			return reduce [join "uint" (size * 8) false]
		]
	]

	ret: switch/default type/kind compose [
		(clang/enum clang/CXTypeKind 'CXType_Void) [
			"void"
		]
		(clang/enum clang/CXTypeKind 'CXType_Float) [
			"float"
		]
		(clang/enum clang/CXTypeKind 'CXType_Double) [
			"double"
		]
		(clang/enum clang/CXTypeKind 'CXType_Pointer) [
			"pointer"
		]
		(clang/enum clang/CXTypeKind 'CXType_ConstantArray) [
			"pointer"
		]
		(clang/enum clang/CXTypeKind 'CXType_IncompleteArray) [
			"pointer"
		]
		(clang/enum clang/CXTypeKind 'CXType_Record) [
			struct?: true
			either none? orig-type [
				type-name: clang/getTypeSpelling type
			][
				type-name: clang/getTypeSpelling orig-type
			]
			type-name-reb: stringfy clang/getCString clang/getTypeSpelling type
			records: ["struct " "union "]
			foreach r records [
				if r = copy/part type-name-reb length? r [
					type-name-reb: skip type-name-reb length? r
				]
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
			size: clang/Type_getSizeOf type
			join "int" (size * 8)
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

	debug ["args:" mold args]

	tmp-func: function r-args body

	debug ["tmp-func:" mold :tmp-func]
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
	orig-type: none
	while [type/kind = clang/enum clang/CXTypeKind 'CXType_Typedef][
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
			skip c-func/name (length? ns c-func)
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
	append ret rejoin ["] (" either none? c-func/lib [to string! lib][c-func/lib] ") ^"" extern-name "^"]^/"]
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
			debug ["padding is needed for field: " c-field/name "offset:" mold get offset "c-field/offset:" mold c-field/offset]
			append ret rejoin [ind "padding" idx " [uint8 [" (c-field/offset - (get offset)) / 8 "]]^/"]
			set offset c-field/offset
		]
		(get offset) > c-field/offset [
			append ret rejoin [ind ";" c-field/name ", merged with the previous field^/"]
			return ret
		]
	]

	append ret rejoin [
		ind
		c-field/name
		" ["
		either none? c-field/typedef [
			debug ["field" mold c-field]
			case [
				string? c-field/type [
					rejoin [write-a-c-type reduce [c-field/type c-field/is-struct?]]
				]
				struct? c-field/type [
					rejoin [write-a-c-type (c-2-reb-type c-field/type none)]
				]
				object? c-field/type [
					either c-field/type/global [
						rejoin ["(" c-field/type/name ")"]
					][
						write-a-rebol-struct c-field/type indent
					]
				]
				'else [
					rejoin ["WRONG " c-field/type]
					debug ["WRONG" c-field/type]
				]
			]
		][
			rejoin ["("	c-field/typedef ")"]
		]
		either c-field/dimension > 1 [
			rejoin [" [" c-field/dimension "]"]
		][
			""
		]
		"]"
		"^/"
	]
	set offset (get offset) + (c-field/size * 8)
	debug ["offset:" get offset]

	ret
]

write-a-rebol-struct: func [
	c-struct [object!]
	indent [integer!]
	/local ret a offset idx anonymous?
][
	ret: copy ""
	insert/dup ret "^-" indent

	either any [none? c-struct/name empty? c-struct/name not c-struct/global][
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

write-a-rebol-enum: func [
	c-enum 	[object!]
	idx		[integer!]
	indent 	[integer!]
	/local ret
][
	ret: copy ""
	insert/dup ret "^-" indent
	either empty? c-enum/name [
		append ret rejoin ["enum" idx]
	][
		append ret c-enum/name
	]
	foreach a c-enum/aliases [
		append ret rejoin [": " a]
	]
	append ret ": [^/"
	foreach [k v] c-enum/key-value [
		loop indent + 1 [append ret "^-"]
		append ret rejoin [k " " v "^/"]
	]

	loop indent [append ret "^-"]
	append ret "]^/"

	ret
]

enum-visitor-fields: mk-cb compose/deep [
	cursor [(clang/CXCursor)]
	parent [(clang/CXCursor)]
	client-data [pointer]
	return: [int32]
][
	debug ["client-data:" to-hex client-data]
	n: make struct! compose/deep [
		[raw-memory: (client-data)]
		v [rebval]
	]
	v: n/v ;c-enum-class
	field-name: clang/getCursorSpelling cursor
	field-name-reb: stringfy clang/getCString field-name
	debug ["field-name:" field-name-reb]
    kind: clang/getCursorKind cursor
    if kind = target-kind: clang/enum clang/CXCursorKind 'CXCursor_EnumConstantDecl [
		append v/key-value reduce [
			field-name-reb 
			clang/getEnumConstantDeclValue cursor
		]
		return clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
	]
	return clang/enum clang/CXChildVisitResult 'CXChildVisit_Recurse
]

struct-visitor-fields: mk-cb compose/deep [
	cursor [(clang/CXCursor)]
	parent [(clang/CXCursor)]
	client-data [pointer]
	return: [int32]
][
	debug ["client-data:" to-hex client-data]
	orig-type: none
	n: make struct! compose/deep [
		[raw-memory: (client-data)]
		v [rebval]
	]
	v: n/v ;c-struct
	field-name: clang/getCursorSpelling cursor
	field-name-reb: stringfy clang/getCString field-name
	debug ["field-name:" field-name-reb]
    kind: clang/getCursorKind cursor
    if kind = target-kind: clang/enum clang/CXCursorKind 'CXCursor_FieldDecl [
		type: clang/getCursorType cursor
		if type/kind = clang/enum clang/CXTypeKind 'CXType_Typedef [
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
		while [type/kind = clang/enum clang/CXTypeKind 'CXType_ConstantArray][
			dim: dim * clang/getArraySize type
			type: clang/getArrayElementType type
			if type/kind = clang/enum clang/CXTypeKind 'CXType_Typedef [
				orig-type: type
				type: clang/getCanonicalType type
			]
		]

		; type could be catgorized as below:
		; 1. a typedef'ed struct
		; 2. a nested struct
		; 3. other atomic type
		debug ["type/kind:" type/kind]
		either any [
			type/kind = clang/enum clang/CXTypeKind 'CXType_Unexposed
			type/kind = clang/enum clang/CXTypeKind 'CXType_Record
		][
			decl-cursor: clang/getTypeDeclaration type
			decl-cursor-kind: clang/getCursorKind decl-cursor
			decl-cursor-name: clang/getCursorSpelling decl-cursor
			decl-cursor-name-reb: stringfy clang/getCString clang/getCursorSpelling decl-cursor
			debug ["decl-cursor-name:" decl-cursor-name-reb]
			clang/disposeString decl-cursor-name
			debug ["decl-cursor-kind:" decl-cursor-kind]

			switch/default decl-cursor-kind compose [
				(clang/enum clang/CXCursorKind 'CXCursor_EnumDecl) [
					field/type: "int32"
				]
				(clang/enum clang/CXCursorKind 'CXCursor_StructDecl) [
					semantic-parent: clang/getCursorSemanticParent decl-cursor
					semantic-parent-kind: clang/getCursorKind semantic-parent
					semantic-parent-name: clang/getCursorSpelling semantic-parent
					debug ["parent-name:" stringfy clang/getCString semantic-parent-name]
					clang/disposeString semantic-parent-name

					lexical-parent: clang/getCursorLexicalParent decl-cursor
					lexical-parent-kind: clang/getCursorKind lexical-parent
					lexical-parent-name: clang/getCursorSpelling lexical-parent
					debug ["lexical parent-name:" stringfy clang/getCString lexical-parent-name]
					clang/disposeString lexical-parent-name

					nested-struct: make struct! compose [
						v: [rebval] (
							make c-struct [
								global: lexical-parent-kind = clang/enum clang/CXCursorKind 'CXCursor_TranslationUnit
								name: decl-cursor-name-reb
							]
						)
					]
					clang/visitChildren decl-cursor addr-of :struct-visitor-fields addr-of nested-struct
					field/type: nested-struct/v
					field/is-struct?: true
					unless any [
						none? orig-type
						orig-type/kind != clang/enum clang/CXTypeKind 'CXType_Typedef
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
				debug ["Unexpected cursor-kind" decl-cursor-kind ", expecting structdecl"]
				return clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
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
		return clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
	]
	clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
]

handle-enum: function [
	cursor [struct!]
	parent [struct!]
	client-data [integer!]
][
	name: clang/getCursorSpelling cursor
	enum-name-reb: stringfy clang/getCString name
	clang/disposeString name
	debug ["enum name:" mold enum-name-reb]
	if empty? enum-name-reb [
		debug ["anonymous enum"]
		parent-type: clang/getCursorType parent
		if parent-type/kind = clang/enum clang/CXTypeKind 'CXType_Typedef [
			name: clang/getCursorSpelling parent
			enum-name-reb: stringfy clang/getCString name
			clang/disposeString name
		]
		debug ["parent type:" parent-type/kind "name:" enum-name-reb]
	]
	n: make struct! compose [
		v: [rebval] (make c-enum-class [name: enum-name-reb])
	]
	clang/visitChildren cursor addr-of :enum-visitor-fields addr-of n
	append global-enums n/v
	debug ["found an enum:" mold n/v]
	return clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
]

add-func: func [
	f [object!]
][
	idx: global-functions/hash/(f/name)
	if none? idx [
		append global-functions/funcs f
		append global-functions/hash reduce [f/name length? global-functions/funcs]
	]
]

handle-function: function [
	cursor [struct!]
	parent [struct!]
	client-data [integer!]
][
	; ignore non-exported functions
	name: clang/getCursorSpelling cursor
	func-name-reb: stringfy clang/getCString name
	clang/disposeString name

	link: clang/getCursorLinkage cursor
	debug [func-name-reb "link:" link]
	unless any [
		link = clang/enum clang/CXLinkageKind 'CXLinkage_External
		link = clang/enum clang/CXLinkageKind 'CXLinkage_UniqueExternal][
		return clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
	]
	func-type: clang/getCursorType cursor
	rtype: clang/getResultType func-type

	rtype-name: clang/getTypeSpelling rtype
	rtype-name-reb: stringfy clang/getCString rtype-name
	clang/disposeString rtype-name
	rtype: c-2-rebol-arg-type rtype
	debug ["rtype:" rtype-name-reb]
	debug ["rtype:" mold rtype]

	c-func: make c-func-class reduce/no-set [
		name: func-name-reb
		return-type: first rtype
		return-struct?: second rtype
		variadic?: not zero? clang/isFunctionTypeVariadic func-type
		abi: clang/getFunctionTypeCallingConv func-type
		availability: clang/getCursorAvailability cursor
	]
	n: clang/Cursor_getNumArguments cursor
	debug ["n:" n]
	i: 0
	type: none
	while [i < n] [
		arg: clang/Cursor_getArgument cursor i
		arg-name: clang/getCursorSpelling arg
		debug ["type" mold type]
		arg-type: c-2-rebol-arg-type clang/getCursorType arg
		c-arg: make c-arg-class [
			name: stringfy clang/getCString arg-name
			type: first arg-type
			is-struct?: second arg-type
		]
		append c-func/args c-arg
		;type-name: clang/getTypeSpelling c-arg/type
		debug rejoin ["parameter:" stringfy clang/getCString arg-name ", type:" mold c-arg/type "^/"]
		;clang/disposeString type-name
		clang/disposeString arg-name

		++ i
	]
	debug ["checking for variadic arguments"]
	add-func c-func
	return clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
]

add-struct: function [
	s [object!]
][
	unless any [none? s/name empty? s/name][
		aliases: join reduce [s/name] s/aliases
		debug ["aliases" mold aliases]
		idx: none
		foreach a aliases [
			unless none? idx: global-structs/hash/(a) [break]
		]
		either none? idx [; new struct
			global-structs/n-structs: global-structs/n-structs + 1
			append global-structs/structs s
			foreach a aliases [
				append global-structs/hash reduce [a global-structs/n-structs]
			]
		][
			os: global-structs/structs/(idx)
			foreach a aliases [
				if none? global-structs/hash/(a) [
					append global-structs/hash reduce [a idx]
				]
				unless any [
					a = os/name
					found? find os/aliases a
				][
					append os/aliases a
				]
			]
			
			if all [
				empty? os/fields
				not empty? s/fields] [; it was just a declaration: typedef struct a a_t;
				os/fields: s/fields
			]
		]
	]
]

handle-struct: function [
	cursor [struct!]
	parent [struct!]
	client-data [integer!]
][
	struct-name: clang/getCursorSpelling cursor
	struct-name-reb: stringfy clang/getCString struct-name
	clang/disposeString struct-name
	debug ["struct-name:" struct-name-reb]

	parent-kind: clang/getCursorKind parent
	debug ["parent-kind:" parent-kind]
	struct-alias: ""
	if parent-kind = target-kind: clang/enum clang/CXCursorKind 'CXCursor_TypedefDecl [
		typedef-name: clang/getCursorSpelling parent
		typedef-name-reb: stringfy clang/getCString typedef-name
		debug ["typedef-name-reb:" typedef-name-reb]
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
	type: clang/getCursorType cursor

	n: make struct! compose [
		v: [rebval] (make c-struct [name: struct-name-reb])
	]
	unless empty? struct-alias [
		append n/v/aliases struct-alias
	]
	clang/visitChildren cursor addr-of :struct-visitor-fields addr-of n
	debug ["found a struct:" mold n/v]
	add-struct n/v
	return clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
]

handle-typedef: function [
	cursor [struct!]
	parent [struct!]
	client-data [integer!]
][
	type: clang/getCursorType cursor
	name: clang/getTypeSpelling type
	name-reb: stringfy clang/getCString name
	clang/disposeString name
	debug ["typedef-name:" name-reb]

	canonical-type: clang/getCanonicalType type
	debug ["canonical type:" canonical-type/kind]
	canonical-name: clang/getTypeSpelling canonical-type
	canonical-name-reb: stringfy clang/getCString canonical-name
	clang/disposeString canonical-name
	debug ["typedef-name:" name-reb "canonical-type:" canonical-name-reb]

	switch canonical-type/kind compose [
		(clang/CXTypeKind/CXType_Record) [
			foreach s global-structs/structs [
				if s/name = canonical-name-reb [
					unless any [
						s/name = name-reb
						found? find s/aliases name-reb
					][
						debug ["adding a struct alias " name-reb "to" canonical-name-reb]
						append s/aliases name-reb
					]
					return clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
				]
			]
		]
		(clang/CXTypeKind/CXType_Enum) [
			debug ["canonical-name-reb0:" mold canonical-name-reb]
			if find/match canonical-name-reb "enum " [
				remove/part canonical-name-reb length? "enum "
				debug ["canonical-name-reb1:" mold canonical-name-reb]
			]
			foreach e global-enums [
				if e/name = canonical-name-reb [
					unless any [
						e/name = name-reb
						found? find e/aliases name-reb
					][
						debug ["adding an enum alias " name-reb "to" canonical-name-reb]
						append e/aliases name-reb
					]
					return clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
				]
			]
		]
	]

	;typedef might be declared before the canonical datatype
	debug ["saving typedefs"]
	parsed-name-reb: split canonical-name-reb " "
	if all [2 <= length? parsed-name-reb
			found? find ["struct" "enum" "union"] first parsed-name-reb][
		canonical-name-reb: second parsed-name-reb
	]

	if name-reb != canonical-name-reb [
		either none? aliases: select global-typedefs canonical-name-reb [
			aliases: reduce [name-reb]
		][
			unless found? find aliases name-reb [
				append aliases name-reb
			]
		]
		append global-typedefs reduce [canonical-name-reb aliases]
	]

	return clang/enum clang/CXChildVisitResult 'CXChildVisit_Recurse
]

handle-union: function [
	cursor [struct!]
	parent [struct!]
	client-data [integer!]
][
	name: clang/getCursorSpelling cursor
	union-name-reb: stringfy clang/getCString name
	clang/disposeString name
	debug ["union name:" mold union-name-reb]
	if empty? union-name-reb [
		debug ["anonymous union"]
		parent-type: clang/getCursorType parent
		if parent-type/kind = clang/enum clang/CXTypeKind 'CXType_Typedef [
			name: clang/getCursorSpelling parent
			union-name-reb: stringfy clang/getCString name
			clang/disposeString name
		]
		debug ["parent type:" parent-type/kind "name:" union-name-reb]
	]
	type: clang/getCursorType cursor
	size: clang/Type_getSizeOf type
	debug ["sizeof" union-name-reb ":" size]
	field: make c-field reduce/no-set [
		name: "fake"
		type: "uint8"
		dimension: size
	]
	s: make c-struct [
		name: union-name-reb
		fields: reduce [field]
	]
	debug ["faked union struct:" mold s]
	add-struct s
	return clang/enum clang/CXChildVisitResult 'CXChildVisit_Continue
]

cursor-visitor: mk-cb compose/deep [
	cursor [(clang/CXCursor)]
	parent [(clang/CXCursor)]
	client-data [pointer]
	return: [int32]
][
	debug ["cursor-visitor"]
	debug ["cursor:" mold cursor]
	kind: clang/getCursorKind cursor
	case compose [
		(kind = clang/enum clang/CXCursorKind 'CXCursor_TypedefDecl) [
			;avoid duplicate visits to enum, struct, etc
			return handle-typedef cursor parent client-data
		]
		(kind = clang/enum clang/CXCursorKind 'CXCursor_EnumDecl) [
			return handle-enum cursor parent client-data
		]
		(kind = clang/enum clang/CXCursorKind 'CXCursor_FunctionDecl) [
			return handle-function cursor parent client-data
		]
		(kind = clang/enum clang/CXCursorKind 'CXCursor_StructDecl) [
			return handle-struct cursor parent client-data
		]
		(kind = clang/enum clang/CXCursorKind 'CXCursor_UnionDecl) [
			return handle-union cursor parent client-data
		]
		'else [
			;name: clang/getCursorSpelling cursor
			name: clang/getCursorSpelling cursor
			name-reb: stringfy clang/getCString name
			clang/disposeString name
			debug ["cursor name: " name-reb "kind: " kind]
			return clang/enum clang/CXChildVisitResult 'CXChildVisit_Recurse
		]
		debug ["check for next cursor"]
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
	tu: make struct! [
		u [pointer] 
	]

	translationUnit: clang/parseTranslationUnit2 index 0
			argv argc ;argv, argc
			0 0 0
			addr-of tu

	unless zero? translationUnit [
		print ["error creating translationUnit: " translationUnit]
		quit
	]

	translationUnit: tu/u

	print-diagnostics translationUnit

	root-cursor: clang/getTranslationUnitCursor translationUnit

	clang/visitChildren root-cursor addr-of :cursor-visitor 0
	clang/disposeTranslationUnit translationUnit
	clang/disposeIndex index
]

write-output: func [
	dest [file!]
	lib [block!] "block of [libname libpath]"
	/local e written-structs s a func-to-expose f write-a-complete-struct idx
][
	;write dest ""

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
	
	write-a-complete-struct: func [
		s [object!]
		/local f ns n
	][
	  	if found? select written-structs s/name [exit]
		debug ["writing a complete struct:" mold s]
		foreach f s/fields [
			if all [
				f/is-struct?
				object? f/type
				f/type/global
			][
				n: f/type/name
				if any [none? n empty? n][
					n: f/typedef
				]
				if found? select global-structs/hash n [
					debug ["trying to find struct for:" mold f]
					ns: pick global-structs/structs (select global-structs/hash n)
					write-a-complete-struct ns
				]
			]
		]
		write/append dest rejoin [write-a-rebol-struct s 1 "^/"]
		export-struct s
	]

	debug ["global-typedefs:" mold global-typedefs]

	foreach e global-enums [
		as: select global-typedefs e/name
		unless none? as [
			foreach a as [
				unless found? find e/aliases a [
					append e/aliases a
				]
			]
		]
	]

	idx: 0
	foreach e global-enums [
		either function? :enum-filter [
			;debug ["enum-filter" :enum-filter]
			if enum-filter e [
				write/append dest rejoin [write-a-rebol-enum e idx 1 "^/"]
			]
		][
			write/append dest rejoin [write-a-rebol-enum e idx 1 "^/"]
		]
		++ idx
	]

	foreach s global-structs/structs [
		as: select global-typedefs s/name
		unless none? as [
			foreach a as [
				unless found? find s/aliases a [
					append s/aliases a
				]
			]
		]
	]

	debug ["all structs with aliases:" mold global-structs/structs]

	foreach s global-structs/structs [
		unless zero? length? s/fields [ ;ex: typedef struct a *pa;
			either function? get 'struct-filter [
				if struct-filter s [
					write-a-complete-struct s ;its dependency might not pass the filter
				]
			][
				;its dependency must have been written, guranteed by C
				write/append dest rejoin [write-a-rebol-struct s 1 "^/"]
				export-struct s
			]
		]
	]

	either function? :function-filter [
		foreach f global-functions/funcs [
			if function-filter f [
				append func-to-expose f
			]
		]
	][
		func-to-expose: global-functions/funcs
	]

	; write all structs required by func
	foreach f func-to-expose [
		foreach a f/args [
			if all [
				a/is-struct?
				not found? select written-structs a/type
			][
				;write the struct and its dependency
				debug ["trying to find struct for:" mold a/type]
				s: pick global-structs/structs (select global-structs/hash a/type)
				write-a-complete-struct s
			]
		]
		if all [
			f/return-struct?
			not found? select written-structs f/return-type
		][
			debug ["trying to find struct for:" mold f/return-type]
			s: pick global-structs/structs (select global-structs/hash f/return-type)
			write-a-complete-struct s
		]
	]

	debug ["exported structs:" mold written-structs]

	default-lib: none
	foreach [libname libpath] lib [
		default-lib: libname
		write/append dest rejoin ["^-" libname ": make library! " mold libpath "^/"]
	]

	foreach f func-to-expose [
		debug ["f:" mold f]
		write/append dest rejoin [write-a-rebol-func f default-lib (get 'function-ns) 1 "^/"]
	]
]

r2utf8-string: function [
	s [any-string!]
][
	bin-arg: to binary! s
	arg: make struct! compose/deep [
		data [uint8 [(1 + length? bin-arg)]]
	]
	change arg join bin-arg #{00}
	arg
]
