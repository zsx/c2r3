REBOL []

tcc: do %../../bindings/libtcc.reb

prog: tcc/compile compose/deep [
	'sysinclude [%/usr/lib/tcc/include %/usr/include]
]
{
	#include <stdlib.h>
	#include <stdio.h>

	void cpuid_string(char *s)
	{
		int a, b, c, d;

		asm volatile ( "cpuid" : "=a"(a), "=b"(b), "=c"(c), "=d"(d) : "0"(0));

		memcpy(s, &b, sizeof(b));
		s += sizeof(b);
		memcpy(s, &d, sizeof(d));
		s += sizeof(d);
		memcpy(s, &c, sizeof(c));
		s += sizeof(c);
		*s = '\0';
	}
}

cpu-string: tcc/load-func prog "cpuid_string" 
	[
		vendor [pointer] "a string/binary that's at least 12-char long"
		return: [void]
	]

vendor: to binary! "unknown_vend" ;at least 12-char long
cpu-string vendor
print ["cpu-string:" to string! vendor]

probe prog
tcc/destroy prog
