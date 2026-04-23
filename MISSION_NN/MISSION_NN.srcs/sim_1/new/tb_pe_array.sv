`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2026 06:12:39 PM
// Design Name: 
// Module Name: tb_pe_array
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
// tb_pe_array.sv - pe_array.sv verification  (Module 2)
// Icarus Verilog 12 compatible - no unpacked arrays as task ports
//
// TC1  A1×B1 all-positive
// TC2  A2×B2 negative weights
// TC3  A3×I  identity - output equals A3
// TC4  pe_rst between layers - no residue
// =============================================================================

`timescale 1ns/1ps

module tb_pe_array;

  localparam N         = 4;
  localparam ACT_W     = 8;
  localparam WGT_W     = 8;
  localparam ACC_W     = 20;
  localparam TOTAL_CYC = 12;

  reg                                    clk, rst, en, pe_rst;
  reg  [0:N-1][ACT_W-1:0]                a_in;
  reg  signed [0:N-1][WGT_W-1:0]         b_in;
  wire signed [ACC_W-1:0]                result [0:N-1][0:N-1];

  pe_array dut (
    .clk(clk),.rst(rst),.en(en),.pe_rst(pe_rst),
    .a_in(a_in),.b_in(b_in),.result(result)
  );

  initial clk=0;
  always #5 clk=~clk;

  integer pass_cnt, fail_cnt, ri, ci;
  initial begin pass_cnt=0; fail_cnt=0; end

  task check;
    input [640-1:0]          name;
    input signed [ACC_W-1:0] got, exp;
    begin
      if (got===exp) begin
        $display("  [PASS] %s  got=%0d",name,got); pass_cnt=pass_cnt+1;
      end else begin
        $display("  [FAIL] %s  got=%0d  exp=%0d",name,got,exp); fail_cnt=fail_cnt+1;
      end
    end
  endtask

  task do_reset;
    begin
      @(negedge clk);rst=1;pe_rst=0;en=1;a_in='0;b_in='0;
      @(posedge clk);#1;@(posedge clk);#1;
      @(negedge clk);rst=0;
    end
  endtask

  task drive;
    input [0:N-1][ACT_W-1:0]        a;
    input signed [0:N-1][WGT_W-1:0] b;
    begin @(negedge clk);a_in=a;b_in=b;@(posedge clk);#1; end
  endtask

  // ── Stimulus tables ───────────────────────────────────────────────────────
  reg [0:TOTAL_CYC-1][0:N-1][ACT_W-1:0]        AS1, AS2, AS3;
  reg signed [0:TOTAL_CYC-1][0:N-1][WGT_W-1:0] BS1, BS2, BS3;
  // Expected: unpacked 2D regs (variable index supported on regs)
  reg signed [ACC_W-1:0] EXP1 [0:N-1][0:N-1];
  reg signed [ACC_W-1:0] EXP2 [0:N-1][0:N-1];
  reg signed [ACC_W-1:0] EXP3 [0:N-1][0:N-1];

  task run_pass;
    input [0:TOTAL_CYC-1][0:N-1][ACT_W-1:0]        at;
    input signed [0:TOTAL_CYC-1][0:N-1][WGT_W-1:0] bt;
    integer c;
    begin for(c=0;c<TOTAL_CYC;c=c+1) drive(at[c],bt[c]); end
  endtask

  initial begin
    // ── TC1 stimulus ──────────────────────────────────────────────────────
    AS1[ 0]={8'd1,8'd0,8'd0,8'd0}; BS1[ 0]={ 8'sd1, 8'sd0, 8'sd0, 8'sd0};
    AS1[ 1]={8'd2,8'd5,8'd0,8'd0}; BS1[ 1]={ 8'sd3, 8'sd2, 8'sd0, 8'sd0};
    AS1[ 2]={8'd3,8'd6,8'd1,8'd0}; BS1[ 2]={ 8'sd0, 8'sd1, 8'sd1, 8'sd0};
    AS1[ 3]={8'd4,8'd7,8'd0,8'd2}; BS1[ 3]={ 8'sd2, 8'sd1, 8'sd0, 8'sd0};
    AS1[ 4]={8'd0,8'd8,8'd1,8'd3}; BS1[ 4]={ 8'sd0, 8'sd0, 8'sd2, 8'sd2};
    AS1[ 5]={8'd0,8'd0,8'd0,8'd0}; BS1[ 5]={ 8'sd0, 8'sd0, 8'sd1, 8'sd1};
    AS1[ 6]={8'd0,8'd0,8'd0,8'd1}; BS1[ 6]={ 8'sd0, 8'sd0, 8'sd0, 8'sd3};
    AS1[ 7]='0;BS1[ 7]='0; AS1[ 8]='0;BS1[ 8]='0;
    AS1[ 9]='0;BS1[ 9]='0; AS1[10]='0;BS1[10]='0; AS1[11]='0;BS1[11]='0;
    EXP1[0][0]=15; EXP1[0][1]=7;  EXP1[0][2]=11; EXP1[0][3]=19;
    EXP1[1][0]=39; EXP1[1][1]=23; EXP1[1][2]=27; EXP1[1][3]=43;
    EXP1[2][0]=1;  EXP1[2][1]=3;  EXP1[2][2]=3;  EXP1[2][3]=1;
    EXP1[3][0]=13; EXP1[3][1]=7;  EXP1[3][2]=3;  EXP1[3][3]=9;

    // ── TC2 stimulus ──────────────────────────────────────────────────────
    AS2[ 0]={8'd2,8'd0,8'd0,8'd0}; BS2[ 0]={ 8'sd1,  8'sd0,  8'sd0,  8'sd0};
    AS2[ 1]={8'd1,8'd0,8'd0,8'd0}; BS2[ 1]={-8'sd3, -8'sd1,  8'sd0,  8'sd0};
    AS2[ 2]={8'd0,8'd4,8'd3,8'd0}; BS2[ 2]={ 8'sd0,  8'sd2,  8'sd2,  8'sd0};
    AS2[ 3]={8'd3,8'd2,8'd0,8'd1}; BS2[ 3]={ 8'sd2,  8'sd1, -8'sd1, -8'sd2};
    AS2[ 4]={8'd0,8'd1,8'd1,8'd2}; BS2[ 4]={ 8'sd0, -8'sd1, -8'sd2,  8'sd3};
    AS2[ 5]={8'd0,8'd0,8'd2,8'd3}; BS2[ 5]={ 8'sd0,  8'sd0,  8'sd1,  8'sd1};
    AS2[ 6]={8'd0,8'd0,8'd0,8'd0}; BS2[ 6]={ 8'sd0,  8'sd0,  8'sd0, -8'sd3};
    AS2[ 7]='0;BS2[ 7]='0; AS2[ 8]='0;BS2[ 8]='0;
    AS2[ 9]='0;BS2[ 9]='0; AS2[10]='0;BS2[10]='0; AS2[11]='0;BS2[11]='0;
    EXP2[0][0]=5;   EXP2[0][1]=-3;  EXP2[0][2]=6;   EXP2[0][3]=-10;
    EXP2[1][0]=-10; EXP2[1][1]=9;   EXP2[1][2]=-7;  EXP2[1][3]=11;
    EXP2[2][0]=7;   EXP2[2][1]=-4;  EXP2[2][2]=6;   EXP2[2][3]=-11;
    EXP2[3][0]=-5;  EXP2[3][1]=6;   EXP2[3][2]=-6;  EXP2[3][3]=7;

    // ── TC3 stimulus (A3 × I) ─────────────────────────────────────────────
    AS3[ 0]={8'd10,8'd0, 8'd0, 8'd0};  BS3[ 0]={8'sd1,8'sd0,8'sd0,8'sd0};
    AS3[ 1]={8'd20,8'd50,8'd0, 8'd0};  BS3[ 1]={8'sd0,8'sd0,8'sd0,8'sd0};
    AS3[ 2]={8'd30,8'd60,8'd11,8'd0};  BS3[ 2]={8'sd0,8'sd1,8'sd0,8'sd0};
    AS3[ 3]={8'd40,8'd70,8'd22,8'd5};  BS3[ 3]={8'sd0,8'sd0,8'sd0,8'sd0};
    AS3[ 4]={8'd0, 8'd80,8'd33,8'd15}; BS3[ 4]={8'sd0,8'sd0,8'sd1,8'sd0};
    AS3[ 5]={8'd0, 8'd0, 8'd44,8'd25}; BS3[ 5]={8'sd0,8'sd0,8'sd0,8'sd0};
    AS3[ 6]={8'd0, 8'd0, 8'd0, 8'd35}; BS3[ 6]={8'sd0,8'sd0,8'sd0,8'sd1};
    AS3[ 7]='0;BS3[ 7]='0; AS3[ 8]='0;BS3[ 8]='0;
    AS3[ 9]='0;BS3[ 9]='0; AS3[10]='0;BS3[10]='0; AS3[11]='0;BS3[11]='0;
    EXP3[0][0]=10; EXP3[0][1]=20; EXP3[0][2]=30; EXP3[0][3]=40;
    EXP3[1][0]=50; EXP3[1][1]=60; EXP3[1][2]=70; EXP3[1][3]=80;
    EXP3[2][0]=11; EXP3[2][1]=22; EXP3[2][2]=33; EXP3[2][3]=44;
    EXP3[3][0]=5;  EXP3[3][1]=15; EXP3[3][2]=25; EXP3[3][3]=35;
  end

  // ── Main ──────────────────────────────────────────────────────────────────
  reg [640-1:0] nm;

  initial begin
    $display("\n======================================================");
    $display("  tb_pe_array - pe_array.sv  N=%0d", N);
    $display("======================================================\n");
    rst=1;en=1;pe_rst=0;a_in='0;b_in='0;
    #1;

    // TC1
    $display("--- TC1: A1 x B1 (all positive, 16 cells) ---");
    do_reset; run_pass(AS1,BS1);
    for(ri=0;ri<N;ri=ri+1) for(ci=0;ci<N;ci=ci+1) begin
      $sformat(nm,"TC1 C[%0d][%0d]",ri,ci);
      check(nm, result[ri][ci], EXP1[ri][ci]);
    end

    // TC2
    $display("\n--- TC2: A2 x B2 (negative weights) ---");
    do_reset; run_pass(AS2,BS2);
    for(ri=0;ri<N;ri=ri+1) for(ci=0;ci<N;ci=ci+1) begin
      $sformat(nm,"TC2 C[%0d][%0d]",ri,ci);
      check(nm, result[ri][ci], EXP2[ri][ci]);
    end

    // TC3
    $display("\n--- TC3: A3 x Identity ---");
    do_reset; run_pass(AS3,BS3);
    for(ri=0;ri<N;ri=ri+1) for(ci=0;ci<N;ci=ci+1) begin
      $sformat(nm,"TC3 C[%0d][%0d]",ri,ci);
      check(nm, result[ri][ci], EXP3[ri][ci]);
    end

    // TC4 - pe_rst between layers
    $display("\n--- TC4: pe_rst between layers (no residue) ---");
    do_reset;
    run_pass(AS1,BS1);
    @(negedge clk); pe_rst=1; a_in='0; b_in='0;
    @(posedge clk);#1;@(posedge clk);#1;
    @(negedge clk); pe_rst=0;
    run_pass(AS3,BS3);
    for(ri=0;ri<N;ri=ri+1) for(ci=0;ci<N;ci=ci+1) begin
      $sformat(nm,"TC4 C[%0d][%0d]",ri,ci);
      check(nm, result[ri][ci], EXP3[ri][ci]);
    end

    $display("\n======================================================");
    $display("  PASSED: %0d   FAILED: %0d",pass_cnt,fail_cnt);
    if (fail_cnt==0)
      $display("  *** ALL TESTS PASSED - pe_array.sv verified ***");
    else
      $display("  *** FAILURES - review above ***");
    $display("======================================================\n");
    $finish;
  end

  initial begin #200000;$display("[TIMEOUT]");$finish;end

endmodule
