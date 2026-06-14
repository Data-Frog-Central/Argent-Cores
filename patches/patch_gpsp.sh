#!/bin/bash
read -r -d '' SF2000_BLOCK << 'EOF' || true
# DartOS
else ifeq ($(platform), dartos)
	TARGET := $(TARGET_NAME)_libretro_$(platform).a
	MIPS:=/opt/mips32-mti-elf/2019.09-03-2/bin/mips-mti-elf-
	CC = $(MIPS)gcc
	CXX = $(MIPS)g++
	AR = $(MIPS)ar
	CFLAGS = -EL -march=mips32 -mtune=mips32 -msoft-float -G0 -mno-abicalls -fno-pic
	CFLAGS += -ffast-math -fomit-frame-pointer -ffunction-sections -fdata-sections 
	CFLAGS += -DSMALL_TRANSLATION_CACHE -DROM_BUFFER_SIZE=16
    CFLAGS += -I../../include
	CFLAGS += -DSF2000
	CXXFLAGS = $(CFLAGS)
	STATIC_LINKING = 1
	HAVE_DYNAREC := 1
	CPU_ARCH := mips

else ifeq ($(platform), rs90)
EOF

escaped_block=$(echo "$SF2000_BLOCK" | sed ':a;N;$!ba;s/\n/\\n/g')
sed -i "s|else ifeq (\$(platform), rs90)|$escaped_block|g" Makefile

read -r -d '' SF2000_BLOCK << 'EOF' || true
#ifndef SF2000
#define GBA_SOUND_FREQUENCY   (64 * 1024)
#else
#define GBA_SOUND_FREQUENCY   (22050)
#endif
EOF

escaped_block=$(echo "$SF2000_BLOCK" | sed ':a;N;$!ba;s/\n/\\n/g')
sed -i "s|#define GBA_SOUND_FREQUENCY   (64 \* 1024)|$escaped_block|g" sound.h

sed -i 's|#if defined(PSP) \|\| defined(PS2)|#if defined(PSP) \|\| defined(PS2) \|\| defined(SF2000)|' mips/mips_stub.S
perl -0777 -i -pe 's/\s*if \(bios_loaded && bios_rom\[0\] != 0x18\)\s*\{\s*if \(selected_bios == official_bios\)\s*show_warning_message\("BIOS image seems incorrect, using built-in BIOS", 2500\);\s*bios_loaded = false;\s*\}//g' libretro/libretro.c