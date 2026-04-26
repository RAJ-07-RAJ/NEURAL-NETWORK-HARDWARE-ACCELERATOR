`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/26/2026 10:48:12 PM
// Design Name: 
// Module Name: stagger
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
// stagger.sv - Input Stagger Unit  (Module 3 of 10)
//
// What it does
// ────────────
//   Takes raw A rows and raw B columns (all N values presented simultaneously
//   each cycle, one element per cycle per row/col) and delays them so that
//   PE[i][j] receives the correct A[i][k] × B[k][j] pair at cycle k+i+j+1.
//
//   Row i of A is delayed by i clock cycles  (shift register depth = i).
//   Col j of B is delayed by j clock cycles  (shift register depth = j).
//   Row 0 / Col 0 → depth 0 → pure wire (combinational passthrough).
//
// Port convention
// ───────────────
//   raw_a[i]  : A[i][k] presented at clock k+1  (k counts from 0)
//   raw_b[j]  : B[k][j] presented at clock k+1
//   a_out[i]  : delayed a fed into left edge of PE row i
//   b_out[j]  : delayed b fed into top edge of PE col j
//
// Implementation
// ──────────────
//   Each row i gets a shift-register of depth i built by a generate loop.
//   Depth 0 → assign out = in  (no register, just wire).
//   Depth d → chain of d flip-flops; output = in delayed by d cycles.
//
// Reset / enable
// ──────────────
//   Synchronous reset (rst) clears all shift register stages.
//   Clock enable (en) freezes all stages when deasserted.
//   pe_rst is NOT connected here - stagger state is structural, not accumulated.
// =============================================================================

`timescale 1ns/1ps
import nn_pkg::*;

module stagger (
  input  logic                             clk,
  input  logic                             rst,
  input  logic                             en,

  // ── Raw inputs from SRAM (all N values simultaneously each cycle) ─────────
  input  logic [0:N-1][ACT_W-1:0]          raw_a,   // activation rows
  input  logic signed [0:N-1][WGT_W-1:0]  raw_b,   // weight columns

  // ── Staggered outputs to pe_array left/top edges ──────────────────────────
  output logic [0:N-1][ACT_W-1:0]          a_out,   // to a_in[row] of pe_array
  output logic signed [0:N-1][WGT_W-1:0]  b_out    // to b_in[col] of pe_array
);

  // ── A shift registers: row i has depth i ─────────────────────────────────
  // sr_a[i][s] = stage s of the shift register for row i
  // s=0 holds the most recently sampled value; s=i-1 is the output tap.
  logic [0:N-1][0:N-1][ACT_W-1:0]          sr_a;

  // ── B shift registers: col j has depth j ─────────────────────────────────
  logic signed [0:N-1][0:N-1][WGT_W-1:0]  sr_b;

  genvar i, j;

  // ── A stagger ─────────────────────────────────────────────────────────────
  generate
    for (i = 0; i < N; i++) begin : stag_a
      if (i == 0) begin
        // Depth 0: combinational passthrough, no register
        assign a_out[0] = raw_a[0];
      end else begin
        // Stage 0: sample raw input
        always_ff @(posedge clk) begin
          if (rst)     sr_a[i][0] <= '0;
          else if (en) sr_a[i][0] <= raw_a[i];
        end
        // Stages 1..i-1: chain
        for (j = 1; j < i; j++) begin : chain_a
          always_ff @(posedge clk) begin
            if (rst)     sr_a[i][j] <= '0;
            else if (en) sr_a[i][j] <= sr_a[i][j-1];
          end
        end
        // Output tap: last stage
        assign a_out[i] = sr_a[i][i-1];
      end
    end
  endgenerate

  // ── B stagger ─────────────────────────────────────────────────────────────
  generate
    for (i = 0; i < N; i++) begin : stag_b
      if (i == 0) begin
        assign b_out[0] = raw_b[0];
      end else begin
        always_ff @(posedge clk) begin
          if (rst)     sr_b[i][0] <= '0;
          else if (en) sr_b[i][0] <= raw_b[i];
        end
        for (j = 1; j < i; j++) begin : chain_b
          always_ff @(posedge clk) begin
            if (rst)     sr_b[i][j] <= '0;
            else if (en) sr_b[i][j] <= sr_b[i][j-1];
          end
        end
        assign b_out[i] = sr_b[i][i-1];
      end
    end
  endgenerate

endmodule
