REBOL []

tcc: do %../../bindings/libtcc.reb

prog: tcc/compile compose/deep [
]
{
	void cpuid(unsigned *a, unsigned *b, unsigned *c, unsigned *d)
	{
		int eax = *a, ebx, ecx, edx;
		//printf("a: 0x%x\n", *a);

		asm volatile (
			"cpuid" 
			: "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx)
			: "0"(eax)
		);
		*a = eax;
		*b = ebx;
		*c = ecx;
		*d = edx;
	}
}

cpuid: tcc/load-func prog "cpuid" 
	[
		eax [pointer]
		ebx [pointer]
		ecx [pointer]
		edx [pointer]
		return: [void]
	]

cpu-string: func [
	/local eax ebx ecx edx
][
	eax: copy #{00000000}
	ebx: copy #{00000000}
	ecx: copy #{00000000}
	edx: copy #{00000000}

	cpuid eax ebx ecx edx
	to string! rejoin [ebx edx ecx]
]

processor-brand: func [
	/local brand i eax ebx ecx edx
][
	brand: copy ""

	for-each i [#{02000080} #{03000080} #{04000080}] [
		eax: copy i
		ebx: copy #{00000000}
		ecx: copy #{00000000}
		edx: copy #{00000000}

		;print ["eax:" mold eax]
		cpuid eax ebx ecx edx
		append brand to string! rejoin [eax ebx ecx edx]
	]

	brand
]

print ["Manufacture ID:" cpu-string]
print ["Processor brand:" processor-brand]

tcc/destroy prog
