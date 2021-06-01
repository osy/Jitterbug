LIBUSBMUXD_CFLAGS := $(shell pkg-config --cflags libusbmuxd-2.0)
LIBUSBMUXD_LDFLAGS := $(shell pkg-config --libs libusbmuxd-2.0)
LIBIMOBILEDEVICE_CFLAGS := $(shell pkg-config --cflags libimobiledevice-1.0)
LIBIMOBILEDEVICE_LDFLAGS := $(shell pkg-config --libs libimobiledevice-1.0)
OPENSSL_CFLAGS := $(shell pkg-config --cflags openssl)
OPENSSL_LDFLAGS := $(shell pkg-config --libs openssl)

CC := gcc
LD := gcc
CFLAGS := -DHAVE_CONFIG_H -ILibraries/include -ILibraries/libimobiledevice -ILibraries/libimobiledevice/common -ILibraries/libimobiledevice/include $(LIBUSBMUXD_CFLAGS) $(LIBIMOBILEDEVICE_CFLAGS) $(OPENSSL_CLFAGS)
LDFLAGS := $(LIBUSBMUXD_LDFLAGS) $(LIBIMOBILEDEVICE_LDFLAGS) $(OPENSSL_LDFLAGS)

# path macros
BUILD_PATH := build

# compile macros
TARGET_NAME := jitterbugpair
ifeq ($(OS),Windows_NT)
	TARGET_NAME := $(addsuffix .exe,$(TARGET_NAME))
endif
TARGET := $(BUILD_PATH)/$(TARGET_NAME)

# src files & obj files
SRC := JitterbugPair/main.c Libraries/libimobiledevice/common/debug.c Libraries/libimobiledevice/common/userpref.c Libraries/libimobiledevice/common/utils.c
OBJ := $(addprefix $(BUILD_PATH)/, $(addsuffix .o, $(notdir $(basename $(SRC)))))

# default rule
default: all

# non-phony targets
$(TARGET): $(OBJ)
	$(LD) $(CFLAGS) $(LDFLAGS) -o $@ $^

$(BUILD_PATH)/%.o: $(BUILD_PATH)/%.c*
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILD_PATH)/%.c: $(SRC)
	mkdir -p $(BUILD_PATH) || true
	cp $^ $(BUILD_PATH)/

# phony rules
.PHONY: all
all: $(TARGET)

.PHONY: clean
clean:
	@echo CLEAN $(CLEAN_LIST)
	@rm -rf $(BUILD_PATH)
