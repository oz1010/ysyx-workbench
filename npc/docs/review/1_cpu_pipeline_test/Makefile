CC      = riscv64-linux-gnu-gcc
CFLAGS  = -march=rv32im -mabi=ilp32 -nostdlib -static -g
LDFLAGS = -T link.ld

TESTS   = s1_fence s2_csrrc s3_branch_fifo s4_slti \
          s5a_mulh s5b_div \
          h1_mstatus h2_csr_raw h3_trap h4_flush_axi \
          m4_srai m5_load_use l5_branch_predict

ELFS    = $(addsuffix .elf, $(TESTS))

all: $(ELFS)

%.elf: %.S link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f $(ELFS)

.PHONY: all clean
