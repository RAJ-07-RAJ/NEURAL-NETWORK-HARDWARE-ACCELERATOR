`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2026 12:11:04 PM
// Design Name: 
// Module Name: PROCESSESING_ELEMENT
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
// pe.sv - Processing Element (Module 1 of 10)
//
// What it does
// ────────────
//   Every clock cycle (when en=1):
//     acc   <= acc + (a_in * b_in)   [MAC - multiply-accumulate]
//     a_out <= a_in                  [pass activation rightward]
//     b_out <= b_in                  [pass weight downward]
//
// Port types
// ──────────
//   a_in  : unsigned activation  (ACT_W bits)
//   b_in  : signed   weight      (WGT_W bits, 2's complement)
//   acc   : signed   accumulator (ACC_W bits)
//
// Reset behaviour
// ───────────────
//   Synchronous active-high reset (rst).
//   Also supports pe_rst - a separate "clear accumulator only" signal
//   used by the FSM between layers without disturbing pipeline registers.
//
// Why signed × unsigned?
// ──────────────────────
//   Weights can be negative (trained parameters).
//   Activations after ReLU are always ≥ 0 (unsigned).
//   SystemVerilog multiplies as signed when either operand is signed,
//   so we sign-extend a_in to PROD_W bits before multiplying.
// =============================================================================

`timescale 1ns/1ps
import nn_pkg::*;

module pe (
  input  logic                  clk,
  input  logic                  rst,      // sync reset - clears everything
  input  logic                  en,       // clock enable (holds state when 0)
  input  logic                  pe_rst,   // clear accumulator only (between layers)

  // ── Systolic data ports ───────────────────────────────────────────────────
  input  logic [ACT_W-1:0]      a_in,     // activation from left  (unsigned)
  input  logic signed [WGT_W-1:0] b_in,   // weight from above     (signed)

  output logic [ACT_W-1:0]      a_out,   // pass to right neighbour
  output logic signed [WGT_W-1:0] b_out, // pass to lower neighbour

  // ── Result ────────────────────────────────────────────────────────────────
  output logic signed [ACC_W-1:0] acc    // accumulated dot-product
);

  // ── Internal: sign-extended activation for signed multiply ────────────────
  // Sign-extend the unsigned a_in to PROD_W so the multiplier is fully signed.
  // This is safe: since a_in is unsigned (always ≥ 0), the MSB extension is 0.
  logic signed [PROD_W-1:0] a_sign_ext;
  assign a_sign_ext = {{(PROD_W-ACT_W){1'b0}}, a_in};  // zero-extend = sign-extend for unsigned

  // ── Product (combinational) ───────────────────────────────────────────────
  logic signed [PROD_W-1:0] product;
  assign product = a_sign_ext * b_in;   // signed × signed → signed PROD_W result

  // ── Pipeline registers ────────────────────────────────────────────────────
  always_ff @(posedge clk) begin
    if (rst) begin
      a_out <= '0;
      b_out <= '0;
      acc   <= '0;
    end
    else if (en) begin
      // Pass-through registers - data flows one PE per clock
      a_out <= a_in;
      b_out <= b_in;

      // Accumulator clear takes priority over MAC
      if (pe_rst)
        acc <= '0;
      else
        acc <= acc + ACC_W'(product);  // width-matched signed addition
    end
  end

endmodule