REBOL []

make object! [
	x64?: switch/default system/platform/2 [
		libc-x64 [ true ]	
	][false]

	lib: make library! %libclang.so

	; pointers
	CXIndex:
	CXTranslationUnit:
	CXClientData:
	CXDiagnostic:
	CXDiagnosticSet:

	CXVisitor: 'pointer

	;enums
	CXChildVisitResult: 
	CXCursorKind:
	CXTypeKind: 'int32

	CXCursorKinds: [
		CXCursor_UnexposedDecl                  1
		CXCursor_StructDecl                     2
		CXCursor_UnionDecl                      3
		CXCursor_ClassDecl                      4
		CXCursor_EnumDecl                       5
		CXCursor_FieldDecl                      6
		CXCursor_EnumConstantDecl               7
		CXCursor_FunctionDecl                   8
		CXCursor_VarDecl                        9
		CXCursor_ParmDecl                       10
		CXCursor_ObjCInterfaceDecl              11
		CXCursor_ObjCCategoryDecl               12
		CXCursor_ObjCProtocolDecl               13
		CXCursor_ObjCPropertyDecl               14
		CXCursor_ObjCIvarDecl                   15
		CXCursor_ObjCInstanceMethodDecl         16
		CXCursor_ObjCClassMethodDecl            17
		CXCursor_ObjCImplementationDecl         18
		CXCursor_ObjCCategoryImplDecl           19
		CXCursor_TypedefDecl                    20
		CXCursor_CXXMethod                      21
		CXCursor_Namespace                      22
		CXCursor_LinkageSpec                    23
		CXCursor_Constructor                    24
		CXCursor_Destructor                     25
		CXCursor_ConversionFunction             26
		CXCursor_TemplateTypeParameter          27
		CXCursor_NonTypeTemplateParameter       28
		CXCursor_TemplateTemplateParameter      29
		CXCursor_FunctionTemplate               30
		CXCursor_ClassTemplate                  31
		CXCursor_ClassTemplatePartialSpecialization  32
		CXCursor_NamespaceAlias                 33
		CXCursor_UsingDirective                 34
		CXCursor_UsingDeclaration               35
		CXCursor_TypeAliasDecl                  36
		CXCursor_ObjCSynthesizeDecl             37
		CXCursor_ObjCDynamicDecl                38
		CXCursor_CXXAccessSpecifier             39

		CXCursor_FirstDecl                      CXCursor_UnexposedDecl
		CXCursor_LastDecl                       CXCursor_CXXAccessSpecifier

		CXCursor_ObjCSuperClassRef              40
		CXCursor_ObjCProtocolRef                41
		CXCursor_ObjCClassRef                   42
		CXCursor_TypeRef                        43
		CXCursor_CXXBaseSpecifier               44
		CXCursor_TemplateRef                    45
		CXCursor_NamespaceRef                   46
		CXCursor_MemberRef                      47
		CXCursor_LabelRef                       48
		CXCursor_OverloadedDeclRef              49
		CXCursor_VariableRef                    50

		CXCursor_LastRef                        CXCursor_VariableRef

		CXCursor_FirstInvalid                   70
		CXCursor_InvalidFile                    70
		CXCursor_NoDeclFound                    71
		CXCursor_NotImplemented                 72
		CXCursor_InvalidCode                    73
		CXCursor_LastInvalid                    CXCursor_InvalidCode

		CXCursor_FirstExpr                      100
		CXCursor_UnexposedExpr                  100
		CXCursor_DeclRefExpr                    101
		CXCursor_MemberRefExpr                  102

		CXCursor_CallExpr                       103

		CXCursor_ObjCMessageExpr                104

		CXCursor_BlockExpr                      105
		CXCursor_IntegerLiteral                 106
		CXCursor_FloatingLiteral                107
		CXCursor_ImaginaryLiteral               108
		CXCursor_StringLiteral                  109
		CXCursor_CharacterLiteral               110
		CXCursor_ParenExpr                      111
		CXCursor_UnaryOperator                  112
		CXCursor_ArraySubscriptExpr             113
		CXCursor_BinaryOperator                 114
		CXCursor_CompoundAssignOperator         115
		CXCursor_ConditionalOperator            116
		CXCursor_CStyleCastExpr                 117
		CXCursor_CompoundLiteralExpr            118
		CXCursor_InitListExpr                   119
		CXCursor_AddrLabelExpr                  120

		CXCursor_StmtExpr                       121
		CXCursor_GenericSelectionExpr           122
		CXCursor_GNUNullExpr                    123
		CXCursor_CXXStaticCastExpr              124
		CXCursor_CXXDynamicCastExpr             125
		CXCursor_CXXReinterpretCastExpr         126
		CXCursor_CXXConstCastExpr               127
		CXCursor_CXXFunctionalCastExpr          128
		CXCursor_CXXTypeidExpr                  129
		CXCursor_CXXBoolLiteralExpr             130
		CXCursor_CXXNullPtrLiteralExpr          131

		CXCursor_CXXThisExpr                    132
		CXCursor_CXXThrowExpr                   133
		CXCursor_CXXNewExpr                     134
		CXCursor_CXXDeleteExpr                  135
		CXCursor_UnaryExpr                      136
		CXCursor_ObjCStringLiteral              137
		CXCursor_ObjCEncodeExpr                 138
		CXCursor_ObjCSelectorExpr               139
		CXCursor_ObjCProtocolExpr               140
		CXCursor_ObjCBridgedCastExpr            141
		CXCursor_PackExpansionExpr              142
		CXCursor_SizeOfPackExpr                 143
		CXCursor_LambdaExpr                     144
		CXCursor_ObjCBoolLiteralExpr            145
		CXCursor_ObjCSelfExpr                   146

		CXCursor_LastExpr                       CXCursor_ObjCSelfExpr

		CXCursor_FirstStmt                      200
		CXCursor_UnexposedStmt                  200
		CXCursor_LabelStmt                      201
		CXCursor_CompoundStmt                   202
		CXCursor_CaseStmt                       203
		CXCursor_DefaultStmt                    204
		CXCursor_IfStmt                         205
		CXCursor_SwitchStmt                     206
		CXCursor_WhileStmt                      207
		CXCursor_DoStmt                         208
		CXCursor_ForStmt                        209
		CXCursor_GotoStmt                       210
		CXCursor_IndirectGotoStmt               211
		CXCursor_ContinueStmt                   212
		CXCursor_BreakStmt                      213
		CXCursor_ReturnStmt                     214

		CXCursor_GCCAsmStmt                     215
		CXCursor_AsmStmt                        CXCursor_GCCAsmStmt

		CXCursor_ObjCAtTryStmt                  216
		CXCursor_ObjCAtCatchStmt                217
		CXCursor_ObjCAtFinallyStmt              218

		CXCursor_ObjCAtThrowStmt                219
		CXCursor_ObjCAtSynchronizedStmt         220
		CXCursor_ObjCAutoreleasePoolStmt        221
		CXCursor_ObjCForCollectionStmt          222
		CXCursor_CXXCatchStmt                   223
		CXCursor_CXXTryStmt                     224
		CXCursor_CXXForRangeStmt                225
		CXCursor_SEHTryStmt                     226
		CXCursor_SEHExceptStmt                  227
		CXCursor_SEHFinallyStmt                 228
		CXCursor_MSAsmStmt                      229
		CXCursor_NullStmt                       230
		CXCursor_DeclStmt                       231
		CXCursor_OMPParallelDirective           232
		CXCursor_OMPSimdDirective               233
		CXCursor_OMPForDirective                234
		CXCursor_OMPSectionsDirective           235
		CXCursor_OMPSectionDirective            236
		CXCursor_OMPSingleDirective             237
		CXCursor_OMPParallelForDirective        238
		CXCursor_OMPParallelSectionsDirective   239
		CXCursor_OMPTaskDirective               240
		CXCursor_OMPMasterDirective             241
		CXCursor_OMPCriticalDirective           242
		CXCursor_OMPTaskyieldDirective          243
		CXCursor_OMPBarrierDirective            244
		CXCursor_OMPTaskwaitDirective           245
		CXCursor_OMPFlushDirective              246
		CXCursor_SEHLeaveStmt                   247
		CXCursor_LastStmt                       CXCursor_SEHLeaveStmt
		CXCursor_TranslationUnit                300
		CXCursor_FirstAttr                      400
		CXCursor_UnexposedAttr                  400
		CXCursor_IBActionAttr                   401
		CXCursor_IBOutletAttr                   402
		CXCursor_IBOutletCollectionAttr         403
		CXCursor_CXXFinalAttr                   404
		CXCursor_CXXOverrideAttr                405
		CXCursor_AnnotateAttr                   406
		CXCursor_AsmLabelAttr                   407
		CXCursor_PackedAttr                     408
		CXCursor_PureAttr                       409
		CXCursor_ConstAttr                      410
		CXCursor_NoDuplicateAttr                411
		CXCursor_CUDAConstantAttr               412
		CXCursor_CUDADeviceAttr                 413
		CXCursor_CUDAGlobalAttr                 414
		CXCursor_CUDAHostAttr                   415
		CXCursor_LastAttr                       CXCursor_CUDAHostAttr

		CXCursor_PreprocessingDirective         500
		CXCursor_MacroDefinition                501
		CXCursor_MacroExpansion                 502
		CXCursor_MacroInstantiation             CXCursor_MacroExpansion
		CXCursor_InclusionDirective             503
		CXCursor_FirstPreprocessing             CXCursor_PreprocessingDirective
		CXCursor_LastPreprocessing              CXCursor_InclusionDirective

		CXCursor_ModuleImportDecl               600
		CXCursor_FirstExtraDecl                 CXCursor_ModuleImportDecl
		CXCursor_LastExtraDecl                  CXCursor_ModuleImportDecl
	]

	CXChildVisitResults: [
		CXChildVisit_Break 0
		CXChildVisit_Continue 1
		CXChildVisit_Recurse 2
	]

	CXTypeKinds: [
		CXType_Invalid  0
		CXType_Unexposed  1

		CXType_Void  2
		CXType_Bool  3
		CXType_Char_U  4
		CXType_UChar  5
		CXType_Char16  6
		CXType_Char32  7
		CXType_UShort  8
		CXType_UInt  9
		CXType_ULong  10
		CXType_ULongLong  11
		CXType_UInt128  12
		CXType_Char_S  13
		CXType_SChar  14
		CXType_WChar  15
		CXType_Short  16
		CXType_Int  17
		CXType_Long  18
		CXType_LongLong  19
		CXType_Int128  20
		CXType_Float  21
		CXType_Double  22
		CXType_LongDouble  23
		CXType_NullPtr  24
		CXType_Overload  25
		CXType_Dependent  26
		CXType_ObjCId  27
		CXType_ObjCClass  28
		CXType_ObjCSel  29
		CXType_FirstBuiltin  CXType_Void
		CXType_LastBuiltin   CXType_ObjCSel

		CXType_Complex  100
		CXType_Pointer  101
		CXType_BlockPointer  102
		CXType_LValueReference  103
		CXType_RValueReference  104
		CXType_Record  105
		CXType_Enum  106
		CXType_Typedef  107
		CXType_ObjCInterface  108
		CXType_ObjCObjectPointer  109
		CXType_FunctionNoProto  110
		CXType_FunctionProto  111
		CXType_ConstantArray  112
		CXType_Vector  113
		CXType_IncompleteArray  114
		CXType_VariableArray  115
		CXType_DependentSizedArray  116
		CXType_MemberPointer  117
	]

	CXLinkageKind: [
		CXLinkage_Invalid	0
		CXLinkage_NoLinkage	1
		CXLinkage_Internal	2
		CXLinkage_UniqueExternal 3
		CXLinkage_External 4
	]

	CXAvailabilityKind: [
		CXAvailability_Available		0
		CXAvailability_Deprecated		1
		CXAvailability_NotAvailable		2
		CXAvailability_NotAccessible	3
	]

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

	CXCursor: make struct! compose [
		(CXCursorKind) kind
		int32 xdata
		pointer [3] data
	]

	CXType: make struct! either x64? [
		compose [
			(CXTypeKind) kind;
			int32 padding 
			pointer [2] data
		]
	][
			(CXTypeKind) kind;
			pointer [2] data
	]

	CXString: make struct! [
		pointer data
		uint32	private_flags
	]

	CXSourceLocation: make struct! [
		pointer [2] ptr_data
		uint32	int_data
	]

	; functions
	createIndex: make routine! compose/deep [[
		excludeDeclarationsFromPCH 	[int32]
		displayDiagnostics 			[int32]
		return: 					[(CXIndex)]
	] (lib) "clang_createIndex" ]


	parseTranslationUnit: make routine! compose/deep [[
		CIdx 					[(CXIndex)]
		source_filename 		[pointer]
		command_line_args 		[pointer]
		num_command_line_args 	[int32]
		unsaved_files 			[pointer]
		num_unsaved_files 		[uint32]
		options 				[uint32]
		return: 				[(CXTranslationUnit)]
	] (lib) "clang_parseTranslationUnit"]

	getTranslationUnitCursor: make routine! compose/deep [[
		unit [(CXTranslationUnit)]
		return: [(CXCursor)]
	] (lib) "clang_getTranslationUnitCursor"]

	disposeTranslationUnit: make routine! compose/deep [[
		unit [(CXTranslationUnit)]
		return: [void]
	] (lib) "clang_disposeTranslationUnit"]

	disposeIndex: make routine! compose/deep [[
		index [(CXIndex)]
		return: [void]
	] (lib) "clang_disposeIndex"]

	visitChildren: make routine! compose/deep [[
		parent 		[(CXCursor)]
		visitor 	[(CXVisitor)]
		client_data [(CXClientData)]
		return: 	[(CXChildVisitResult)]
	] (lib) "clang_visitChildren"]

	getCursorKind: make routine! compose/deep [[
		cursor [(CXCursor)]
		return: [(CXCursorKind)]
	] (lib) "clang_getCursorKind"]

	getCursorType: make routine! compose/deep [[
		cursor [(CXCursor)]
		return: [(CXType)]
	] (lib) "clang_getCursorType"]

	getCursorSpelling: make routine! compose/deep [[
		cursor [(CXCursor)]
		return: [(CXString)]
	] (lib) "clang_getCursorSpelling"]

	getTypeSpelling: make routine! compose/deep [[
		type [(CXType)]
		return: [(CXString)]
	] (lib) "clang_getTypeSpelling"]

	getCanonicalType: make routine! compose/deep [[
		type [(CXType)]
		return: [(CXType)]
	] (lib) "clang_getCanonicalType"]

	getFunctionTypeCallingConv: make routine! compose/deep [[
		T [(CXType)]
		return: [int32]
	] (lib) "clang_getFunctionTypeCallingConv"]

	isFunctionTypeVariadic: make routine! compose/deep [[
		type [(CXType)]
		return: [uint32]
	] (lib) "clang_isFunctionTypeVariadic"]

	getResultType: make routine! compose/deep [[
		type [(CXType)]
		return: [(CXType)]
	] (lib) "clang_getResultType"]

	Cursor_getNumArguments: make routine! compose/deep [[
		unit [(CXCursor)]
		return: [int32]
	] (lib) "clang_Cursor_getNumArguments"]

	Cursor_getArgument: make routine! compose/deep [[
		unit [(CXCursor)]
		index [uint32]
		return: [(CXCursor)]
	] (lib) "clang_Cursor_getArgument"]

	getCursorLocation: make routine! compose/deep [[
		cursor [(CXCursor)]
		return: [(CXSourceLocation)]
	] (lib) "clang_getCursorLocation"]

	getPresumedLocation: make routine! compose/deep [[
		location	[(CXSourceLocation)]
		filename 	[pointer] "CXString"
		line	 	[pointer] "uisigned"
		column		[pointer] "unsigned"
		return: [void]
	] (lib) "clang_getPresumedLocation"]

	getNumDiagnostics: make routine! compose/deep [[
		unit [(CXTranslationUnit)]
		return: [uint32]
	] (lib) "clang_getNumDiagnostics"]

	getDiagnostic: make routine! compose/deep [[
		unit 	[(CXTranslationUnit)]
		index	[uint32]
		return: [(CXDiagnostic)]
	] (lib) "clang_getDiagnostic"]

	formatDiagnostic: make routine! compose/deep [[
		diagnostic 	[(CXDiagnostic)]
		format		[uint32]
		return: 	[(CXString)]
	] (lib) "clang_formatDiagnostic"]

	disposeDiagnostic: make routine! compose/deep [[
		diagnostic 	[(CXDiagnostic)]
		return: [void]
	] (lib) "clang_disposeDiagnostic"]

	getCString: make routine! compose/deep [[
		string [(CXString)]
		return: [pointer]
	] (lib) "clang_getCString"]

	disposeString: make routine! compose/deep [[
		string [(CXString)]
		return: [void]
	] (lib) "clang_disposeString"]

	getArrayElementType: make routine! compose/deep [[
		T [(CXType)]
		return: [(CXType)]
	] (lib) "clang_getArrayElementType"]

	getNumElements: make routine! compose/deep [[
		T [(CXType)]
		return: [int64]
	] (lib) "clang_getNumElements"]

	getArraySize: make routine! compose/deep [[
		T [(CXType)]
		return: [int64]
	] (lib) "clang_getArraySize"]

	Type_getSizeOf: make routine! compose/deep [[
		T [(CXType)]
		return: [int64]
	] (lib) "clang_Type_getSizeOf"]

	Type_getAlignOf: make routine! compose/deep [[
		T [(CXType)]
		return: [int64]
	] (lib) "clang_Type_getAlignOf"]

	Type_getOffsetOf: make routine! compose/deep [[
		T [(CXType)]
		S [pointer]
		return: [int64]
	] (lib) "clang_Type_getOffsetOf"]

	getTypeDeclaration: make routine! compose/deep [[
		T [(CXType)]
		return: [(CXCursor)]
	] (lib) "clang_getTypeDeclaration"]

	getCursorSemanticParent: make routine! compose/deep [[
		cursor [(CXCursor)]
		return: [(CXCursor)]
	] (lib) "clang_getCursorSemanticParent"]

	getCursorLexicalParent: make routine! compose/deep [[
		cursor [(CXCursor)]
		return: [(CXCursor)]
	] (lib) "clang_getCursorLexicalParent"]

	getCursorLinkage: make routine! compose/deep [[
		cursor [(CXCursor)]
		return: [int32]
		abi: default
	] (lib) "clang_getCursorLinkage"]

	getCursorAvailability: make routine! compose/deep [[
		cursor [(CXCursor)]
		return: [int32]
		abi: default
	] (lib) "clang_getCursorAvailability"]

	getFieldDeclBitWidth: make routine! compose/deep [[
		C [(CXCursor)]
		return: [int32]
	] (lib) "clang_getFieldDeclBitWidth"]

	getEnumDeclIntegerType: make routine! compose/deep [[
		C [(CXCursor)]
		return: [(CXType)]
		abi: default
	] (lib) "clang_getEnumDeclIntegerType"]

	getEnumConstantDeclValue: make routine! compose/deep [[
		C [(CXCursor)]
		return: [int64]
		abi: default
	] (lib) "clang_getEnumConstantDeclValue"]

]
