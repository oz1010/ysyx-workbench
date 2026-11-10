#include "VIfu.h"
#include "verilated.h"
#include <cstdio>
#include <cstdlib>

static VIfu dut;

static void check(bool condition, const char* message)
{
    if (!condition) {
        std::fprintf(stderr, "FAIL: %s\n", message);
        std::exit(1);
    }
}

static void tick()
{
    dut.clock = 0;
    dut.eval();
    dut.clock = 1;
    dut.eval();
    dut.clock = 0;
    dut.eval();
}

static void reset(unsigned pc = 0x30000000)
{
    dut.io_reset_pc = pc;
    dut.io_cache_req_ready = 0;
    dut.io_cache_rsp_valid = 0;
    dut.io_cache_rsp_data = 0;
    dut.io_cache_rsp_error = 0;
    dut.io_out_ready = 1;
    dut.io_exRedirect_valid = 0;
    dut.io_wbRedirect_valid = 0;
    dut.reset = 1;
    tick();
    tick();
    dut.reset = 0;
    dut.eval();
}

static void request(unsigned pc)
{
    dut.io_cache_req_ready = 1;
    dut.eval();
    check(dut.io_cache_req_valid && dut.io_cache_req_addr == pc, "fetch address");
    tick();
    dut.io_cache_req_ready = 0;
    dut.eval();
}

int main(int argc, char** argv)
{
    Verilated::commandArgs(argc, argv);
    reset();
    request(0x30000000);
    dut.io_exRedirect_valid = 1;
    dut.io_exRedirect_target = 0x30000100;
    tick();
    dut.io_exRedirect_valid = 0;
    dut.eval();
    for (int i = 0; i < 3; ++i) {
        check(!dut.io_cache_req_valid, "redirect must drain old request first");
        tick();
    }
    dut.io_cache_rsp_valid = 1;
    dut.io_cache_rsp_data = 0x00100513;
    dut.eval();
    check(!dut.io_out_valid, "late wrong-path response must be discarded");
    tick();
    dut.io_cache_rsp_valid = 0;
    request(0x30000100);

    dut.io_out_ready = 0;
    dut.io_cache_rsp_valid = 1;
    dut.io_cache_rsp_data = 0x00200293;
    tick();
    dut.io_cache_rsp_valid = 0;
    dut.io_cache_rsp_data = 0;
    dut.eval();
    for (int i = 0; i < 3; ++i) {
        check(dut.io_out_valid && dut.io_out_bits_pc == 0x30000100 &&
              dut.io_out_bits_inst == 0x00200293, "buffered response must remain stable");
        check(!dut.io_cache_req_valid, "buffer must drain before next request");
        tick();
    }
    dut.io_out_ready = 1;
    tick();
    request(0x30000104);

    dut.io_cache_rsp_valid = 1;
    dut.io_exRedirect_valid = 1;
    dut.io_exRedirect_target = 0x30000200;
    dut.io_wbRedirect_valid = 1;
    dut.io_wbRedirect_target = 0x30000300;
    dut.eval();
    check(!dut.io_out_valid, "same-cycle redirect must discard response");
    tick();
    dut.io_cache_rsp_valid = 0;
    dut.io_exRedirect_valid = 0;
    dut.io_wbRedirect_valid = 0;
    request(0x30000300);
    reset(0x0f000000);
    request(0x0f000000);
    reset();
    request(0x30000000);
    dut.io_cache_rsp_valid = 1;
    dut.io_cache_rsp_error = 1;
    dut.io_cache_rsp_data = 0x00000013;
    dut.eval();
    check(dut.io_out_valid && dut.io_out_bits_expt_en &&
          dut.io_out_bits_expt_cause == 1 &&
          dut.io_out_bits_expt_tval == 0x30000000, "fetch access fault");
    tick();
    dut.io_cache_rsp_valid = 0;
    dut.io_cache_rsp_error = 0;
    std::puts("PASS IFU: redirect, WB priority, backpressure, reset, access fault");
    dut.final();
}
