`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/26/2026 10:49:30 PM
// Design Name: 
// Module Name: tb_stagger
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
// tb_stagger.sv - Testbench for stagger.sv  (Module 3 verification)
// Icarus Verilog 12 compatible
//
// Test plan
// ─────────
//   TC1  Full matrix pass   - feed A1 rows / B1 cols raw; verify all staggered
//                             outputs match the golden schedule cycle-by-cycle
//   TC2  Per-row delay      - impulse test: feed unique value on one row at a
//                             time; confirm it appears at a_out[i] exactly i
//                             cycles later and on no other output
//   TC3  Per-col delay      - same impulse test for B columns / b_out
//   TC4  rst clears state   - mid-stream rst zeroes all shift reg stages;
//                             output goes 0 immediately after deassertion
//   TC5  en=0 freeze        - hold en=0; all stages frozen; output unchanged
//   TC6  Stagger → PE array - wire stagger directly to pe_array; verify final
//                             C = A1 × B1 using raw (unstaggered) TB inputs
// =============================================================================

`timescale 1ns/1ps

module tb_stagger;

  localparam N         = 4;
  localparam ACT_W     = 8;
  localparam WGT_W     = 8;
  localparam ACC_W     = 20;
  localparam RAW_CYCS  = 4;    // N cycles of real data
  localparam TOT_CYCS  = 12;   // RAW_CYCS + flush

  // ── DUT signals ──────────────────────────────────────────────────────────
  reg                                  clk, rst, en;
  reg  [0:N-1][ACT_W-1:0]              raw_a;
  reg  signed [0:N-1][WGT_W-1:0]      raw_b;
  wire [0:N-1][ACT_W-1:0]             a_out;
  wire signed [0:N-1][WGT_W-1:0]      b_out;

  stagger dut (
    .clk(clk),.rst(rst),.en(en),
    .raw_a(raw_a),.raw_b(raw_b),
    .a_out(a_out),.b_out(b_out)
  );

  // ── TC6: pe_array wired directly after stagger ────────────────────────────
  reg  pe_rst_sig;
  wire signed [ACC_W-1:0] result [0:N-1][0:N-1];

  pe_array u_arr (
    .clk(clk),.rst(rst),.en(en),.pe_rst(pe_rst_sig),
    .a_in(a_out),.b_in(b_out),.result(result)
  );

  initial clk=0;
  always #5 clk=~clk;

  integer pass_cnt, fail_cnt, i, j;
  reg [640-1:0] nm;
  initial begin pass_cnt=0; fail_cnt=0; end

  // ── Scalar check tasks ────────────────────────────────────────────────────
  task check_u;   // unsigned ACT_W
    input [640-1:0]   name;
    input [ACT_W-1:0] got, exp;
    begin
      if (got===exp) begin $display("  [PASS] %s got=%0d",name,got); pass_cnt=pass_cnt+1; end
      else           begin $display("  [FAIL] %s got=%0d exp=%0d",name,got,exp); fail_cnt=fail_cnt+1; end
    end
  endtask

  task check_s;   // signed WGT_W
    input [640-1:0]          name;
    input signed [WGT_W-1:0] got, exp;
    begin
      if (got===exp) begin $display("  [PASS] %s got=%0d",name,got); pass_cnt=pass_cnt+1; end
      else           begin $display("  [FAIL] %s got=%0d exp=%0d",name,got,exp); fail_cnt=fail_cnt+1; end
    end
  endtask

  task check_acc;
    input [640-1:0]          name;
    input signed [ACC_W-1:0] got, exp;
    begin
      if (got===exp) begin $display("  [PASS] %s got=%0d",name,got); pass_cnt=pass_cnt+1; end
      else           begin $display("  [FAIL] %s got=%0d exp=%0d",name,got,exp); fail_cnt=fail_cnt+1; end
    end
  endtask

  // ── Reset ─────────────────────────────────────────────────────────────────
  task do_reset;
    begin
      @(negedge clk); rst=1; en=1; raw_a='0; raw_b='0; pe_rst_sig=0;
      @(posedge clk);#1;@(posedge clk);#1;
      @(negedge clk); rst=0;
    end
  endtask

  task tick;
    input [0:N-1][ACT_W-1:0]        a;
    input signed [0:N-1][WGT_W-1:0] b;
    begin
      @(negedge clk); raw_a=a; raw_b=b;
      @(posedge clk); #1;
    end
  endtask

  // ── Golden schedule for A1/B1 ─────────────────────────────────────────────
  // Raw: raw_a[i] = A[i][k] at cycle k+1, 0 thereafter (k=0..N-1)
  // A1=[1,2,3,4;5,6,7,8;1,0,1,0;2,3,0,1]
  // B1=[1,2,1,0;3,1,0,2;0,1,2,1;2,0,1,3]

  reg [0:TOT_CYCS-1][0:N-1][ACT_W-1:0]        RAW_A1;
  reg signed [0:TOT_CYCS-1][0:N-1][WGT_W-1:0] RAW_B1;

  // Expected staggered outputs per cycle (from Python golden above)
  reg [0:TOT_CYCS-1][0:N-1][ACT_W-1:0]        EXP_A;
  reg signed [0:TOT_CYCS-1][0:N-1][WGT_W-1:0] EXP_B;

  // Expected C1 = A1 x B1
  reg signed [ACC_W-1:0] EXP_C [0:N-1][0:N-1];

  initial begin
    // Raw A rows (all rows fed simultaneously each cycle)
    // c=1: k=0 → A[i][0]
    RAW_A1[ 0]={8'd1,8'd5,8'd1,8'd2}; RAW_B1[ 0]={8'sd1, 8'sd2, 8'sd1, 8'sd0};
    // c=2: k=1 → A[i][1]
    RAW_A1[ 1]={8'd2,8'd6,8'd0,8'd3}; RAW_B1[ 1]={8'sd3, 8'sd1, 8'sd0, 8'sd2};
    // c=3: k=2 → A[i][2]
    RAW_A1[ 2]={8'd3,8'd7,8'd1,8'd0}; RAW_B1[ 2]={8'sd0, 8'sd1, 8'sd2, 8'sd1};
    // c=4: k=3 → A[i][3]
    RAW_A1[ 3]={8'd4,8'd8,8'd0,8'd1}; RAW_B1[ 3]={8'sd2, 8'sd0, 8'sd1, 8'sd3};
    // c=5..12: zeros (flush)
    RAW_A1[ 4]='0; RAW_B1[ 4]='0; RAW_A1[ 5]='0; RAW_B1[ 5]='0;
    RAW_A1[ 6]='0; RAW_B1[ 6]='0; RAW_A1[ 7]='0; RAW_B1[ 7]='0;
    RAW_A1[ 8]='0; RAW_B1[ 8]='0; RAW_A1[ 9]='0; RAW_B1[ 9]='0;
    RAW_A1[10]='0; RAW_B1[10]='0; RAW_A1[11]='0; RAW_B1[11]='0;

    // Expected staggered a_out per cycle (from Python golden)
    // Formula: a_out[i] after tick c = A[i][c-max(0,i-1)] if index valid
    // Effective delay: 0 cycles for i=0,1;  1 cycle for i=2;  2 cycles for i=3
    EXP_A[ 0]={8'd1, 8'd5, 8'd0, 8'd0};  // c=0
    EXP_A[ 1]={8'd2, 8'd6, 8'd1, 8'd0};  // c=1
    EXP_A[ 2]={8'd3, 8'd7, 8'd0, 8'd2};  // c=2
    EXP_A[ 3]={8'd4, 8'd8, 8'd1, 8'd3};  // c=3
    EXP_A[ 4]={8'd0, 8'd0, 8'd0, 8'd0};  // c=4
    EXP_A[ 5]={8'd0, 8'd0, 8'd0, 8'd1};  // c=5
    EXP_A[ 6]='0; EXP_A[ 7]='0; EXP_A[ 8]='0; EXP_A[ 9]='0;
    EXP_A[10]='0; EXP_A[11]='0;

    EXP_B[ 0]={8'sd1, 8'sd2, 8'sd0, 8'sd0};  // c=0
    EXP_B[ 1]={8'sd3, 8'sd1, 8'sd1, 8'sd0};  // c=1
    EXP_B[ 2]={8'sd0, 8'sd1, 8'sd0, 8'sd0};  // c=2
    EXP_B[ 3]={8'sd2, 8'sd0, 8'sd2, 8'sd2};  // c=3
    EXP_B[ 4]={8'sd0, 8'sd0, 8'sd1, 8'sd1};  // c=4
    EXP_B[ 5]={8'sd0, 8'sd0, 8'sd0, 8'sd3};  // c=5
    EXP_B[ 6]='0; EXP_B[ 7]='0; EXP_B[ 8]='0; EXP_B[ 9]='0;
    EXP_B[10]='0; EXP_B[11]='0;

    // Expected C = A1 x B1
    EXP_C[0][0]=15; EXP_C[0][1]=7;  EXP_C[0][2]=11; EXP_C[0][3]=19;
    EXP_C[1][0]=39; EXP_C[1][1]=23; EXP_C[1][2]=27; EXP_C[1][3]=43;
    EXP_C[2][0]=1;  EXP_C[2][1]=3;  EXP_C[2][2]=3;  EXP_C[2][3]=1;
    EXP_C[3][0]=13; EXP_C[3][1]=7;  EXP_C[3][2]=3;  EXP_C[3][3]=9;
  end

  integer c;
  reg [0:N-1][ACT_W-1:0]             cur_ra;
  reg signed [0:N-1][WGT_W-1:0]     cur_rb;
  reg [0:N-1][ACT_W-1:0]             cur_ea;
  reg signed [0:N-1][WGT_W-1:0]     cur_eb;

  initial begin
    $display("\n======================================================");
    $display("  tb_stagger - stagger.sv  N=%0d", N);
    $display("======================================================\n");
    rst=1; en=1; raw_a='0; raw_b='0; pe_rst_sig=0;
    #1; // let init settle

    // ════════════════════════════════════════════════════════════════════════
    // TC1: Full matrix pass - verify staggered outputs cycle by cycle
    // ════════════════════════════════════════════════════════════════════════
    $display("--- TC1: Full A1/B1 pass - stagger output vs golden (all cycles) ---");
    do_reset;
    for (c=0; c<TOT_CYCS; c=c+1) begin
      cur_ra = RAW_A1[c]; cur_rb = RAW_B1[c];
      tick(cur_ra, cur_rb);
      cur_ea = EXP_A[c]; cur_eb = EXP_B[c];
      // Check all 4 rows of a_out
      for (i=0; i<N; i=i+1) begin
        $sformat(nm,"TC1 c=%0d a_out[%0d]",c+1,i);
        check_u(nm, a_out[i], cur_ea[i]);
      end
      // Check all 4 cols of b_out
      for (i=0; i<N; i=i+1) begin
        $sformat(nm,"TC1 c=%0d b_out[%0d]",c+1,i);
        check_s(nm, b_out[i], cur_eb[i]);
      end
    end

    // ════════════════════════════════════════════════════════════════════════
    // TC2: Per-row delay verification (A impulse test)
    // Feed impulse value 77+i on row i only, all other rows 0
    // Confirm a_out[i] = 77+i appears exactly i cycles later
    // and all other a_out remain 0 at that moment
    // ════════════════════════════════════════════════════════════════════════
    $display("\n--- TC2: Per-row delay - impulse test (a_out[i] delayed i cycles) ---");
    for (i=0; i<N; i=i+1) begin
      reg [ACT_W-1:0] impulse_val;
      integer wait_cyc, k;
      impulse_val = 8'd77 + i;
      do_reset;

      // Drive impulse on row i for one cycle, zeros elsewhere
      @(negedge clk);
      raw_a = '0;
      raw_a[i] = impulse_val;
      raw_b = '0;
      @(posedge clk); #1;

      // Drive zeros for remaining cycles while we wait for output
      // depth i: output appears after max(i-1,0) additional ticks
      // (registers fire on same posedge as input; depth=i means i-1 flush cycles needed)
      for (wait_cyc=0; wait_cyc<(i>0?i-1:0); wait_cyc=wait_cyc+1) begin
        $sformat(nm,"TC2 row%0d pre-delay c=%0d a_out[%0d]=0",i,wait_cyc+1,i);
        check_u(nm, a_out[i], 8'd0);
        tick('0, '0);
      end

      $sformat(nm,"TC2 row%0d output appears at tick=%0d",i,(i>0?i-1:0));
      check_u(nm, a_out[i], impulse_val);

      // All other rows must be 0 at this exact cycle
      for (k=0; k<N; k=k+1) begin
        if (k != i) begin
          $sformat(nm,"TC2 row%0d other a_out[%0d]=0",i,k);
          check_u(nm, a_out[k], 8'd0);
        end
      end
    end

    // ════════════════════════════════════════════════════════════════════════
    // TC3: Per-col delay verification (B impulse test)
    // Same idea: impulse on raw_b[j] → b_out[j] delayed j cycles
    // ════════════════════════════════════════════════════════════════════════
    $display("\n--- TC3: Per-col delay - impulse test (b_out[j] delayed j cycles) ---");
    for (i=0; i<N; i=i+1) begin
      reg signed [WGT_W-1:0] bval;
      integer wc, k2;
      bval = -8'sd10 - i;   // use negative to also verify signed pass-through
      do_reset;

      @(negedge clk);
      raw_b    = '0;
      raw_b[i] = bval;
      raw_a    = '0;
      @(posedge clk); #1;

      for (wc=0; wc<(i>0?i-1:0); wc=wc+1) begin
        $sformat(nm,"TC3 col%0d pre-delay c=%0d b_out[%0d]=0",i,wc+1,i);
        check_s(nm, b_out[i], 8'sd0);
        tick('0, '0);
      end

      $sformat(nm,"TC3 col%0d output at tick=%0d val=%0d",i,(i>0?i-1:0),bval);
      check_s(nm, b_out[i], bval);

      for (k2=0; k2<N; k2=k2+1) begin
        if (k2 != i) begin
          $sformat(nm,"TC3 col%0d other b_out[%0d]=0",i,k2);
          check_s(nm, b_out[k2], 8'sd0);
        end
      end
    end

    // ════════════════════════════════════════════════════════════════════════
    // TC4: rst clears all shift register stages
    // Drive 3 cycles of data, assert rst mid-stream, check outputs go to 0
    // ════════════════════════════════════════════════════════════════════════
    $display("\n--- TC4: rst clears shift register state ---");
    do_reset;
    // Feed data for 3 cycles so deep shift regs have non-zero state
    tick(RAW_A1[0], RAW_B1[0]);
    tick(RAW_A1[1], RAW_B1[1]);
    tick(RAW_A1[2], RAW_B1[2]);
    // Assert rst
    @(negedge clk); rst=1; raw_a='0; raw_b='0;
    @(posedge clk); #1;
    @(negedge clk); rst=0;
    // One cycle after deassertion: all outputs must be 0
    @(posedge clk); #1;
    for (i=0; i<N; i=i+1) begin
      $sformat(nm,"TC4 a_out[%0d]=0 after rst",i); check_u(nm, a_out[i], 8'd0);
      $sformat(nm,"TC4 b_out[%0d]=0 after rst",i); check_s(nm, b_out[i], 8'sd0);
    end

    // ════════════════════════════════════════════════════════════════════════
    // TC5: en=0 freezes all stages
    // Cycle 1 (en=1): feed data; row 0 passthrough so a_out[0] = value
    // Cycle 2 (en=0): feed different data; a_out[0] must stay unchanged
    // Cycle 3 (en=1): feed zeros; a_out[0] must update again
    // ════════════════════════════════════════════════════════════════════════
    $display("\n--- TC5: en=0 freezes shift registers (test on depth-2 row2) ---");
    do_reset;
    // Seed row2 (depth=2): drive 55 at c=0 → appears at a_out[2] after c=1
    en=1;
    @(negedge clk); raw_a={8'd0,8'd0,8'd55,8'd0}; raw_b='0;
    @(posedge clk); #1;   // c=0: sr[2][0]=55
    // c=1 en=1: sr[2][1] should latch sr[2][0]=55 → a_out[2] becomes 55
    @(negedge clk); raw_a='0;
    @(posedge clk); #1;
    check_u("TC5 a_out[2]=55 en=1 c=1", a_out[2], 8'd55);

    // c=2: en=0 - drive different value - sr[2][1] must stay 55
    @(negedge clk); en=0; raw_a={8'd0,8'd0,8'd99,8'd0};
    @(posedge clk); #1;
    check_u("TC5 a_out[2]=55 frozen en=0", a_out[2], 8'd55);

    // c=3: en=1, raw=0 → sr[2][1] now latches sr[2][0], which was frozen at 55→now 0
    @(negedge clk); en=1; raw_a='0;
    @(posedge clk); #1;
    // sr[2][0] was frozen at 99 (en=0 didn't update). en re-enabled:
    // sr[2][1] <- sr[2][0]=99. a_out[2]=99.
    // Actually en=0 froze sr[2][0] too - it stays at 55 (the value from c=0).
    // At c=3 en=1: sr[2][1] <- sr[2][0]=55 (frozen val). a_out[2]=55 still.
    // At c=4 en=1 raw=0: sr[2][0]<-0, sr[2][1]<-55. a_out[2]=55.
    // At c=5 en=1 raw=0: sr[2][0]<-0, sr[2][1]<-0.  a_out[2]=0.
    @(negedge clk); raw_a='0; @(posedge clk); #1;  // c=4
    @(negedge clk); raw_a='0; @(posedge clk); #1;  // c=5
    check_u("TC5 a_out[2]=0 drained after re-enable", a_out[2], 8'd0);

    // ════════════════════════════════════════════════════════════════════════
    // TC6: Stagger wired to PE array - end-to-end multiply using raw inputs
    // Feed raw A1/B1 rows/cols; after TOT_CYCS the PE array result = A1×B1
    // This is the integration proof: stagger + pe_array = correct matmul
    // ════════════════════════════════════════════════════════════════════════
    $display("\n--- TC6: Stagger + PE array integration (raw inputs → C=A1×B1) ---");
    @(negedge clk); rst=1; pe_rst_sig=1; en=1; raw_a='0; raw_b='0;
    @(posedge clk);#1;@(posedge clk);#1;
    @(negedge clk); rst=0; pe_rst_sig=0;

    for (c=0; c<TOT_CYCS; c=c+1) begin
      cur_ra = RAW_A1[c]; cur_rb = RAW_B1[c];
      tick(cur_ra, cur_rb);
    end

    // Verify all 16 results
    for (i=0; i<N; i=i+1) begin
      for (j=0; j<N; j=j+1) begin
        $sformat(nm,"TC6 C[%0d][%0d]",i,j);
        check_acc(nm, result[i][j], EXP_C[i][j]);
      end
    end

    // ── Summary ───────────────────────────────────────────────────────────
    $display("\n======================================================");
    $display("  PASSED: %0d   FAILED: %0d", pass_cnt, fail_cnt);
    if (fail_cnt==0)
      $display("  *** ALL TESTS PASSED - stagger.sv verified ***");
    else
      $display("  *** FAILURES - review above ***");
    $display("======================================================\n");
    $finish;
  end

  initial begin #500000; $display("[TIMEOUT]"); $finish; end

endmodule
