```
$ make world.opt install
make -C byterun  all
make[1]: Entering directory '/data/data/com.termux/files/home/ocaml/byterun'
gcc -O2 -fno-strict-aliasing -fwrapv -Wall  -g -D_FILE_OFFSET_BITS=64 -D_REENTRANT -DCAML_NAME_SPACE  -Wl,-E -Wl,-E -o ocamlrun prims.o libcamlrun.a -lm  -lcurses -lpthread
libcamlrun.a(signals.o): In function `caml_try_leave_blocking_section_default':
/data/data/com.termux/files/home/ocaml/byterun/signals.c:101: undefined reference to `__atomic_exchange_4'
clang-6.0: error: linker command failed with exit code 1 (use -v to see invocation)
make[1]: *** [Makefile:181: ocamlrun] Error 1
make[1]: Leaving directory '/data/data/com.termux/files/home/ocaml/byterun'
make: *** [Makefile:384: coldstart] Error 2


termux 0.63

uname -a
Linux localhost 3.18.31-perf-g2830021-00101-g31fe6a0 #1 SMP PREEMPT Thu Mar 29 04:06:50 CDT 2018 armv7l Android

branch
* termux-4.06.1

ld -v                                               
GNU ld (GNU Binutils) 2.30
```
