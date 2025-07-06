VERIFY_NAME := verify

all: verify

verify: verify.sby
	sby -f $^

.PHONY: all verify

clean:
	@rm -rf $(VERIFY_NAME) $(VERIFY_NAME)_basic
