REBOL []

tcc: do %../../bindings/libtcc.reb

tcc-state: tcc/tcc_new
c-source: to binary! {
int square(int i)
^{
	return i * i;
^}
^@}

if negative? tcc/tcc_compile_string tcc-state c-source [
	do make error! "Failed to compile c"
]

;find out the needed memory size
m-size: tcc/tcc_relocate tcc-state 0

m-buf: make binary! m-size

if negative? tcc/tcc_relocate tcc-state m-buf [
	do make error! "Failed to relocate"
]

s-square: to binary! "square^@"
if zero? ptr-square: tcc/tcc_get_symbol tcc-state s-square [
	do make error! rejoin ["Failed to find symbol " to string! s-square]
]

square: make routine! compose [
	[
		i [int32]
		return: [int32]
	]
	(ptr-square)
]

;call square

print ["square of 2:" square 2]
print ["square of 5:" square 5]
