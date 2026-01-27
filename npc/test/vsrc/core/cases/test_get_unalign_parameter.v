`timescale 1ns/1ps

module test_get_unalign_parameter(
    input wire [7:0] case_num
);
    // Parameters
    parameter ADDR_WIDTH = 32;
    
    // Testbench signals
    logic [`INST_CODE_W-1:0] inst_code;
    logic [ADDR_WIDTH-1:0] addr;
    logic [7:0] len;
    logic [2:0] size;
    logic [7:0] strb;
    logic [1:0] shift_val;
    
    // Test procedure
    initial begin
        $display("Case%d: test_get_unalign_parameter start", case_num);
        
        // Test SB instruction with different alignments
        test_single_case(`INST_SB, 32'h00000000, 0, 0, {4'h1,4'h0}, 0, "SB at aligned address 0");
        test_single_case(`INST_SB, 32'h00000001, 0, 0, {4'h2,4'h0}, 1, "SB at address 1");
        test_single_case(`INST_SB, 32'h00000002, 0, 0, {4'h4,4'h0}, 2, "SB at address 2");
        test_single_case(`INST_SB, 32'h00000003, 0, 0, {4'h8,4'h0}, 3, "SB at address 3");
        
        // Test SH instruction with different alignments
        test_single_case(`INST_SH, 32'h00000000, 0, 1, {4'h3,4'h0}, 0, "SH at aligned address 0");
        test_single_case(`INST_SH, 32'h00000001, 0, 1, {4'h6,4'h0}, 1, "SH at address 1");
        test_single_case(`INST_SH, 32'h00000002, 0, 1, {4'hc,4'h0}, 2, "SH at address 2");
        test_single_case(`INST_SH, 32'h00000003, 1, 1, {4'h8,4'h1}, 3, "SH at address 3");
        
        // Test SW instruction with different alignments
        test_single_case(`INST_SW, 32'h00000000, 0, 2, {4'hf,4'h0}, 0, "SW at aligned address 0");
        test_single_case(`INST_SW, 32'h00000001, 1, 2, {4'he,4'h1}, 1, "SW at address 1");
        test_single_case(`INST_SW, 32'h00000002, 1, 2, {4'hc,4'h3}, 2, "SW at address 2");
        test_single_case(`INST_SW, 32'h00000003, 1, 2, {4'h8,4'h7}, 3, "SW at address 3");
        
        // // Test some random cases
        // test_single_case(`INST_SB, 32'h12345678, "SB at random address");
        // test_single_case(`INST_SH, 32'hABCDEF12, "SH at random address");
        // test_single_case(`INST_SW, 32'hDEADBEEF, "SW at random address");

        $display("Case%d: test_get_unalign_parameter done", case_num);
    end
    
    // Task to test a single case and display results
    task test_single_case(input [15:0] code, input [ADDR_WIDTH-1:0] address, input [7:0] check_len, input [2:0] check_size, input [3:0] check_strb[0:1], input [1:0] check_shift_val, string description);
        begin
            bit check_error = 0;

            // Call the task
            get_unalign_parameter(code, address, len, size, strb, shift_val);
            if (len!=check_len ||
                size!=check_size ||
                strb[0 +: 4]!=check_strb[0] ||
                strb[4 +: 4]!=check_strb[1] ||
                shift_val!=check_shift_val
                ) check_error=1;
            
            if (check_error) begin
                // Display results
                $display("Test case: %s", description);
                $display("  Instruction: 0x%04h, Address: 0x%08h", code, address);
                $display("  Results:");
                $display("    len:        %0d %0d",         len,        check_len);
                $display("    size:       %0d %0d",         size,       check_size);
                $display("    strb[0]:    0x%01h 0x%01h",   strb[0],    check_strb[0]);
                $display("    strb[1]:    0x%01h 0x%01h",   strb[1],    check_strb[1]);
                $display("    shift_val:  %0d %0d",         shift_val,  check_shift_val);
                $display("  ----------------------------");
                $error("Test case failed");
            end
        end
    endtask

endmodule
