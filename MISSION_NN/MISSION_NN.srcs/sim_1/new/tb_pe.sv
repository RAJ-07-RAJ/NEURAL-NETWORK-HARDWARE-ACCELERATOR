`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2026 12:51:49 PM
// Design Name: 
// Module Name: tb_pe
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// =============================================================================
// tb_pe.sv - Testbench for pe.sv  (Module 1 verification)
// Compatible with Icarus Verilog 12 (iverilog -g2012)
//
// Test plan
//   TC1  Basic MAC          - 4 cycles, hand-calculated expected values
//   TC2  Signed weights     - negative b_in, 2's complement arithmetic
//   TC3  Pass-through regs  - a_out/b_out delayed exactly 1 cycle
//   TC4  pe_rst             - clears acc mid-stream; pipeline regs unaffected
//   TC5  en=0 hold          - all registers frozen when en=0
// =============================================================================

`timescale 1ns/1ps

module tb_pe;

  localparam ACT_W  = 8;
  localparam WGT_W  = 8;
  localparam ACC_W  = 20;

  // DUT signals
  reg                      clk, rst, en, pe_rst;
  reg  [ACT_W-1:0]         a_in;
  reg  signed [WGT_W-1:0]  b_in;
  wire [ACT_W-1:0]         a_out;
  wire signed [WGT_W-1:0]  b_out;
  wire signed [ACC_W-1:0]  acc;

  // DUT
  pe dut (
    .clk(clk), .rst(rst), .en(en), .pe_rst(pe_rst),
    .a_in(a_in), .b_in(b_in),
    .a_out(a_out), .b_out(b_out), .acc(acc)
  );

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  integer pass_cnt, fail_cnt;
  initial begin pass_cnt = 0; fail_cnt = 0; end

  task check_acc;
    input [640-1:0]          name;
    input signed [ACC_W-1:0] got, exp;
    begin
      if (got === exp) begin
        $display("  [PASS] %s  got=%0d", name, got);
        pass_cnt = pass_cnt + 1;
      end else begin
        $display("  [FAIL] %s  got=%0d  exp=%0d", name, got, exp);
        fail_cnt = fail_cnt + 1;
      end
    end
  endtask

  task check_act;
    input [640-1:0]    name;
    input [ACT_W-1:0]  got, exp;
    begin
      if (got === exp) begin
        $display("  [PASS] %s  got=%0d", name, got);
        pass_cnt = pass_cnt + 1;
      end else begin
        $display("  [FAIL] %s  got=%0d  exp=%0d", name, got, exp);
        fail_cnt = fail_cnt + 1;
      end
    end
  endtask

  task check_wgt;
    input [640-1:0]           name;
    input signed [WGT_W-1:0]  got, exp;
    begin
      if (got === exp) begin
        $display("  [PASS] %s  got=%0d", name, got);
        pass_cnt = pass_cnt + 1;
      end else begin
        $display("  [FAIL] %s  got=%0d  exp=%0d", name, got, exp);
        fail_cnt = fail_cnt + 1;
      end
    end
  endtask

  task tick;
    input [ACT_W-1:0]         a;
    input signed [WGT_W-1:0]  b;
    input                     pr;
    begin
      @(negedge clk);
      a_in = a; b_in = b; pe_rst = pr;
      @(posedge clk); #1;
    end
  endtask

  task do_reset;
    begin
      @(negedge clk);
      rst = 1; a_in = 0; b_in = 0; pe_rst = 0;
      @(posedge clk); #1;
      @(posedge clk); #1;
      @(negedge clk); rst = 0;
    end
  endtask

  initial begin
    $display("\n======================================================");
    $display("  tb_pe  -  pe.sv verification");
    $display("  ACT_W=%0d  WGT_W=%0d  ACC_W=%0d", ACT_W, WGT_W, ACC_W);
    $display("======================================================\n");

    rst = 1; en = 1; pe_rst = 0; a_in = 0; b_in = 0;

    // ------------------------------------------------------------------
    // TC1: Basic MAC - 4 accumulation cycles
    //   c1: 0 + 2*3 = 6
    //   c2: 6 + 4*5 = 26
    //   c3: 26 + 1*7 = 33
    //   c4: 33 + 3*2 = 39
    // ------------------------------------------------------------------
    $display("--- TC1: Basic MAC (4 cycles) ---");
    do_reset;
    tick(8'd2, 8'sd3,  0);  check_acc("TC1-c1 acc=6 ", acc, 20'sd6);
    tick(8'd4, 8'sd5,  0);  check_acc("TC1-c2 acc=26", acc, 20'sd26);
    tick(8'd1, 8'sd7,  0);  check_acc("TC1-c3 acc=33", acc, 20'sd33);
    tick(8'd3, 8'sd2,  0);  check_acc("TC1-c4 acc=39", acc, 20'sd39);

    // ------------------------------------------------------------------
    // TC2: Negative weights
    //   c1: 0 + 5*(-3) = -15
    //   c2: -15 + 2*(-4) = -23
    //   c3: -23 + 10*1 = -13
    // ------------------------------------------------------------------
    $display("\n--- TC2: Signed negative weights ---");
    do_reset;
    tick(8'd5,  -8'sd3, 0);  check_acc("TC2-c1 acc=-15", acc, -20'sd15);
    tick(8'd2,  -8'sd4, 0);  check_acc("TC2-c2 acc=-23", acc, -20'sd23);
    tick(8'd10,  8'sd1, 0);  check_acc("TC2-c3 acc=-13", acc, -20'sd13);

    // ------------------------------------------------------------------
    // TC3: Pass-through pipeline registers
    // ------------------------------------------------------------------
    $display("\n--- TC3: Pass-through registers ---");
    do_reset;
    tick(8'd42, 8'sd11, 0);
    check_act("TC3-c1 a_out=42", a_out, 8'd42);
    check_wgt("TC3-c1 b_out=11", b_out, 8'sd11);
    tick(8'd99, 8'sd77, 0);
    check_act("TC3-c2 a_out=99", a_out, 8'd99);
    check_wgt("TC3-c2 b_out=77", b_out, 8'sd77);
    tick(8'd0,  -8'sd1, 0);
    check_act("TC3-c3 a_out=0 ", a_out, 8'd0);
    check_wgt("TC3-c3 b_out=-1", b_out, -8'sd1);

    // ------------------------------------------------------------------
    // TC4: pe_rst clears only accumulator; pipeline regs still flow
    //   c1: acc=3*4=12
    //   c2: pe_rst=1 → acc=0, but a_out=5, b_out=6
    //   c3: acc=0+2*2=4
    // ------------------------------------------------------------------
    $display("\n--- TC4: pe_rst clears acc only ---");
    do_reset;
    tick(8'd3, 8'sd4, 0);
    check_acc("TC4-c1 acc=12 before pe_rst",      acc, 20'sd12);
    tick(8'd5, 8'sd6, 1);
    check_acc("TC4-c2 acc=0  during pe_rst",       acc, 20'sd0);
    check_act("TC4-c2 a_out=5 (pipe unaffected)",  a_out, 8'd5);
    check_wgt("TC4-c2 b_out=6 (pipe unaffected)",  b_out, 8'sd6);
    tick(8'd2, 8'sd2, 0);
    check_acc("TC4-c3 acc=4  after pe_rst",        acc, 20'sd4);

    // ------------------------------------------------------------------
    // TC5: en=0 freezes everything
    //   c1 en=1: (a=7, b=3) → acc=21
    //   c2 en=0: drive a=9,b=9 → acc stays 21, a_out stays 7
    //   c3 en=1: (a=1, b=1) → acc=22
    // ------------------------------------------------------------------
    $display("\n--- TC5: en=0 hold ---");
    do_reset;
    en = 1;
    tick(8'd7, 8'sd3, 0);
    check_acc("TC5-c1 acc=21 en=1",        acc, 20'sd21);

    @(negedge clk); en = 0; a_in = 8'd9; b_in = 8'sd9; pe_rst = 0;
    @(posedge clk); #1;
    check_acc("TC5-c2 acc=21 frozen en=0", acc, 20'sd21);
    check_act("TC5-c2 a_out=7 frozen",     a_out, 8'd7);

    en = 1;
    tick(8'd1, 8'sd1, 0);
    check_acc("TC5-c3 acc=22 resumed",     acc, 20'sd22);

    // ------------------------------------------------------------------
    $display("\n======================================================");
    $display("  PASSED: %0d   FAILED: %0d", pass_cnt, fail_cnt);
    if (fail_cnt == 0)
      $display("  *** ALL TESTS PASSED - pe.sv verified *** ");
    else
      $display("  *** FAILURES - review above ***");
    $display("======================================================\n");
//    $finish;
  end

  initial begin #10000; $display("[TIMEOUT]"); $finish; end

endmodule