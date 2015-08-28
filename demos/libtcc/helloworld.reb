REBOL []

tcc: do %../../bindings/libtcc.reb

prog: tcc/compile [ 
	'sysinclude [%/usr/lib/tcc/include %/usr/include]
	'define ["INC" 2]
]
{
	#include <stdio.h>

	void hw (void)
	^{
		printf("hello, world\n");
	^}

	int square (int i)
	^{
		return i * i;
	^}

	void inc(int i)
	^{
		return i + INC;
	^}
}

hw: tcc/load-func prog "hw" 
	[
		return: [void]
	]

square: tcc/load-func prog "square"
	[
		i [int32]
		return: [int32]
	]

inc: tcc/load-func prog "inc" 
	[
		i [int32]
		return: [int32]
	]

hw ;prints hellow, world

print ["square of 2:" square 2]

print ["inc on 2:" inc 2]

tcc/destroy prog
