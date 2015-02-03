REBOL []

;recycle/torture
function-filter: func [
	f [object!]
][
	all [
		found? find/match f/name "SDL_"
		f/name != "SDL_main"
		f/availability = clang/enum clang/CXAvailabilityKind 'CXAvailability_Available
	]
]

function-ns: func [
	f [object!]
][
	either found? find/match f/name "SDL_" [
		"SDL_"
	][
		""
	]
]

struct-filter: func [
	s [object!]
][
	if found? find/match s/name "SDL" [return true]
	foreach a s/aliases [
		if found? find/match a "SDL" [return true]
	]
	false
]

enum-filter: func [
	e [object!]
][
	if any [
		empty? e/name
		empty? e/key-value
	][
		return false
	]
	if found? find/match e/name "SDL" [return true]
	foreach a e/aliases [
		if found? find/match a/name "SDL" [return true]
	]
	false
]

OUTPUT: %sdl2-binding.reb

do %../lib/c2r3.reb

argv-data: compose [
	(r2utf8-string "c2r3.reb")
	(r2utf8-string "-I/usr/lib/clang/3.5.0/include")
	(r2utf8-string "-fsyntax-only")
	(r2utf8-string "-D_REENTRANT")
	(r2utf8-string "-I/usr/include/SDL2")
	(r2utf8-string "/usr/include/SDL2/SDL.h")
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
write-output OUTPUT ["sdl2" %libSDL2.so]
write/append OUTPUT {

	SDL_INIT_TIMER:          to integer! #00000001
	SDL_INIT_AUDIO:          to integer! #00000010
	SDL_INIT_VIDEO:          to integer! #00000020  ;/**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
	SDL_INIT_JOYSTICK:       to integer! #00000200  ;/**< SDL_INIT_JOYSTICK implies SDL_INIT_EVENTS */
	SDL_INIT_HAPTIC:         to integer! #00001000
	SDL_INIT_GAMECONTROLLER: to integer! #00002000  ;/**< SDL_INIT_GAMECONTROLLER implies SDL_INIT_JOYSTICK */
	SDL_INIT_EVENTS:         to integer! #00004000
	SDL_INIT_NOPARACHUTE:    to integer! #00100000  ;/**< Don't catch fatal signals */
	SDL_INIT_EVERYTHING: (
					SDL_INIT_TIMER or SDL_INIT_AUDIO or SDL_INIT_VIDEO or SDL_INIT_EVENTS or
					SDL_INIT_JOYSTICK or SDL_INIT_HAPTIC or SDL_INIT_GAMECONTROLLER
				)

	SDL_WINDOWPOS_UNDEFINED_MASK:    to integer! #1FFF0000
	SDL_WINDOWPOS_UNDEFINED_DISPLAY: function [X]  [SDL_WINDOWPOS_UNDEFINED_MASK or X]
	SDL_WINDOWPOS_UNDEFINED:         SDL_WINDOWPOS_UNDEFINED_DISPLAY 0
	SDL_WINDOWPOS_ISUNDEFINED: function [X] [(X and (to integer! #FFFF0000)) == SDL_WINDOWPOS_UNDEFINED_MASK]

	SDL_WINDOWPOS_CENTERED_MASK:    to integer! #2FFF0000
	SDL_WINDOWPOS_CENTERED_DISPLAY: function [X]  [SDL_WINDOWPOS_CENTERED_MASK or X]
	SDL_WINDOWPOS_CENTERED:         SDL_WINDOWPOS_CENTERED_DISPLAY 0
	SDL_WINDOWPOS_ISCENTERED: function [X] [(X and (to integer! #FFFF0000)) == SDL_WINDOWPOS_CENTERED_MASK]
]
}