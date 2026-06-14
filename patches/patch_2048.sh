#!/bin/bash
read -r -d '' SF2000_BLOCK << 'EOF' || true
# DartOS
else ifeq ($(platform), dartos)
    TARGET := $(TARGET_NAME)_libretro_$(platform).a
    MIPS=/opt/mips32-mti-elf/2019.09-03-2/bin/mips-mti-elf-
    CC = $(MIPS)gcc
    CXX = $(MIPS)g++
    AR = $(MIPS)ar
    CFLAGS =-EL -march=mips32 -mtune=mips32 -msoft-float -ffast-math -fomit-frame-pointer
    CFLAGS+=-G0 -mno-abicalls -fno-pic -ffreestanding
    CFLAGS+=-fno-use-cxa-atexit
    CFLAGS+=-DSF2000
    CFLAGS+=-D__LIBRETRO__
    CXXFLAGS=$(CFLAGS)
    STATIC_LINKING := 1

else ifeq ($(platform), emscripten)
EOF

escaped_block=$(echo "$SF2000_BLOCK" | sed ':a;N;$!ba;s/\n/\\n/g')
sed -i "s|else ifeq (\$(platform), emscripten)|$escaped_block|g" Makefile.libretro
