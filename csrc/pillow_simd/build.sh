#!/bin/sh
cd "${0%build.sh}" || exit 1

[ -d src ] || git clone git@github.com:luapower/pillow-simd-upstream.git src

build() {
	${X}gcc -msse4.1 -O3 -c -Isrc/src/libImaging -I. $C \
		-DHAVE_PROTOTYPES \
		-DSTDC_HEADERS \
		src/src/libImaging/Resample.c \
		src/src/libImaging/Storage.c \
		src/src/libImaging/Copy.c \
		src/src/libImaging/Palette.c \
		Python.c \
		pillow_simd.c
	${X}gcc *.o -shared -o ../../bin/$P/$D $L
	rm -f      ../../bin/$P/$A
	${X}ar rcs ../../bin/$P/$A *.o
	rm *.o
}

if [ "$OSTYPE" = "msys" ]; then
	P=mingw64 L="-s -static-libgcc" D=pillow_simd.dll A=pillow_simd.a build
elif [ "${OSTYPE#darwin}" != "$OSTYPE" ]; then
	P=osx64 C="-arch x86_64" L="-arch x86_64 -install_name @rpath/libboxblur.dylib" \
	D=libpillow_simd.dylib A=libpillow_simd.a build
else
	P=linux64 C=-fPIC L="-s -static-libgcc" D=libpillow_simd.so A=libpillow_simd.a build
fi
