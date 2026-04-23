//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2026 05:48:15 PM
// Design Name: 
// Module Name: pe_array
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
// pe_array.sv - Systolic PE Array  (Module 2 of 10)
//
// Instantiates N×N PE modules. Data flows:
//   Horizontal : a_out of PE[i][j] → a_in of PE[i][j+1]  (right)
//   Vertical   : b_out of PE[i][j] → b_in of PE[i+1][j]  (down)
//
// Output: unpacked 2-D array of accumulators - iverilog/Vivado compatible.
// =============================================================================

`timescale 1ns/1ps
import nn_pkg::*;

module pe_array (
  input  logic                              clk,
  input  logic                              rst,
  input  logic                              en,
  input  logic                              pe_rst,

  // Left-edge activation inputs  (from stagger unit, one per row)
  input  logic [0:N-1][ACT_W-1:0]           a_in,

  // Top-edge weight inputs       (from stagger unit, one per col)
  input  logic signed [0:N-1][WGT_W-1:0]   b_in,

  // All PE accumulator outputs   (to drain unit)
  output logic signed [ACC_W-1:0]           result [0:N-1][0:N-1]
);

  // ── Horizontal systolic wires  a_wire[row][col] ──────────────────────────
  // col 0 = boundary input, col N = sink (unused)
  logic        [0:N-1][0:N][ACT_W-1:0]           a_wire;

  // ── Vertical systolic wires   b_wire[row][col] ──────────────────────────
  // row 0 = boundary input, row N = sink (unused)
  logic signed [0:N][0:N-1][WGT_W-1:0]           b_wire;

  // ── Connect boundary inputs ───────────────────────────────────────────────
  genvar gi;
  generate
    for (gi = 0; gi < N; gi++) begin : bind_inputs
      assign a_wire[gi][0] = a_in[gi];
      assign b_wire[0][gi] = b_in[gi];
    end
  endgenerate

  // ── 2-D PE grid ──────────────────────────────────────────────────────────
  genvar i, j;
  generate
    for (i = 0; i < N; i++) begin : row
      for (j = 0; j < N; j++) begin : col
        pe u_pe (
          .clk    (clk),
          .rst    (rst),
          .en     (en),
          .pe_rst (pe_rst),
          .a_in   (a_wire[i][j]),
          .b_in   (b_wire[i][j]),
          .a_out  (a_wire[i][j+1]),
          .b_out  (b_wire[i+1][j]),
          .acc    (result[i][j])
        );
      end
    end
  endgenerate

endmodule
