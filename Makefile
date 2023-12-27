# Makefile for building port binaries
#
# Makefile targets:
#
# all					  build the wg binary
# clean         clean build products and intermediates
#
# Variables to override:
#
# MIX_APP_PATH  path to the build directory
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# ERL_CFLAGS	additional compiler flags for files using Erlang header files
# ERL_EI_INCLUDE_DIR include path to ei.h (Required for crosscompile)
# ERL_EI_LIBDIR path to libei.a (Required for crosscompile)
# LDFLAGS	linker flags for linking all binaries
# ERL_LDFLAGS	additional linker flags for projects referencing Erlang libraries
#
ifeq ($(MIX_APP_PATH),)
calling_from_make:
	mix compile
endif

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj

TOP := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
DL = $(TOP)/dl

TOOLS_VER = 13f4ac4cb74b5a833fa7f825ba785b1e5774e84f
TOOLS = $(DL)/wireguard-tools-$(TOOLS_VER)

# Disable unneeded Wireguard features
# see https://git.zx2c4.com/wireguard-tools/about/
MAKE_ENV += WITH_SYSTEMDUNITS=no WITH_BASHCOMPLETION=no WITH_WGQUICK=no

# Let Wireguard Makefile determine platform if we are
# compiling for the host platform
ifneq ($(TARGET_OS),)
MAKE_ENV += PLATFORM=$(TARGET_OS)
endif

# This is needed until https://github.com/nerves-project/nerves/issues/705 is fixed
TARGET_ARCH=

all: $(BUILD) $(PREFIX) $(TOOLS) $(PREFIX)/wg

$(BUILD)/Makefile: $(TOOLS)
	cp -R $(TOOLS)/src/* $(BUILD)/

$(PREFIX)/wg: $(BUILD)/Makefile
	$(MAKE_ENV) $(MAKE) -C $(BUILD) -j$(shell nproc)
	@install -m 0755 $(BUILD)/wg $(PREFIX)/wg

$(PREFIX) $(BUILD) $(DL):
	mkdir -p $@

$(TOOLS): $(DL)
	@echo "  DL      $(notdir $@)"
	git clone https://git.zx2c4.com/wireguard-tools $@ 2>/dev/null
	git -C $@ checkout $(TOOLS_VER) 2>/dev/null

mix_clean:
	rm -rf $(BUILD) $(PREFIX)

clean: 
	mix clean

# Don't echo commands unless the caller exports "V=1"
${V}.SILENT:
