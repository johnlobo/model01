CC ?= cc

Z80EX_VERSION := 1.1.21
Z80EX_ARCHIVE  := .cache/z80ex-$(Z80EX_VERSION).tar.gz
Z80EX_DIR      := .cache/z80ex-$(Z80EX_VERSION)
Z80EX_URL      := https://sourceforge.net/projects/z80ex/files/z80ex/$(Z80EX_VERSION)/z80ex-$(Z80EX_VERSION).tar.gz/download
Z80EX_SHA256   := 6f5e521d068a614b41e10180ad4ae45b1bc258ec28c962543feb9078856c2530

GAME_BIN := ../obj/model01.bin
GAME_NOI := ../obj/model01.noi
RUNNER   := run_engine

CFLAGS += -std=c99 -Wall -Wextra -Werror -O2
Z80EX_CFLAGS := -I$(Z80EX_DIR) -I$(Z80EX_DIR)/include \
	-DWORDS_LITTLE_ENDIAN -DZ80EX_VERSION_STR=1.1.21 \
	-DZ80EX_API_REVISION=1 -DZ80EX_VERSION_MAJOR=1 \
	-DZ80EX_VERSION_MINOR=21 -DZ80EX_RELEASE_TYPE=

.PHONY: test architecture game clean

test: architecture game
	$(MAKE) $(RUNNER)
	./$(RUNNER) $(GAME_BIN) $(GAME_NOI)

architecture:
	sh ./check_architecture.sh ..

game:
	$(MAKE) -C ..

$(RUNNER): .cache/run_engine.o .cache/z80ex.o
	$(CC) $^ -o $@

.cache/run_engine.o: run_engine.c $(Z80EX_DIR)/z80ex.c
	$(CC) $(CFLAGS) $(Z80EX_CFLAGS) -c $< -o $@

.cache/z80ex.o: $(Z80EX_DIR)/z80ex.c
	$(CC) -std=c99 -O2 $(Z80EX_CFLAGS) -c $< -o $@

$(Z80EX_ARCHIVE):
	@mkdir -p .cache
	curl --fail --location --retry 3 --output $@ '$(Z80EX_URL)'
	@echo '$(Z80EX_SHA256)  $@' | sha256sum --check --status || \
		{ echo 'Z80Ex archive checksum mismatch' >&2; rm -f $@; exit 1; }

$(Z80EX_DIR)/z80ex.c: $(Z80EX_ARCHIVE)
	@mkdir -p $(Z80EX_DIR)
	tar -xzf $< --strip-components=2 -C $(Z80EX_DIR)
	@touch $@

clean:
	rm -f $(RUNNER)
	rm -rf .cache
