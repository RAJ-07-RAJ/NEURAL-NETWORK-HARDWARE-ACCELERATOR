`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2026 12:13:08 PM
// Design Name: 
// Module Name: nn_pkg
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
// nn_pkg.sv - Shared parameters for the NN accelerator
// All modules import this package so bit-widths are consistent everywhere.
//
// Accumulator width derivation:
//   Worst-case single product : (2^ACT_W - 1) * (2^WGT_W - 1)
//                             = 255 * 255 = 65025  → needs 16 bits
//   After N=4 accumulations   : 4 * 65025 = 260100 → needs 18 bits
//   +2 guard bits for margin  → ACC_W = 20 bits
// =============================================================================

package nn_pkg;

  // ── Array size ──────────────────────────────────────────────────────────────
  parameter int unsigned N      = 4;      // PE array is N×N

  // ── Data widths ─────────────────────────────────────────────────────────────
  parameter int unsigned ACT_W  = 8;      // activation / input  (unsigned)
  parameter int unsigned WGT_W  = 8;      // weight               (signed 2's complement)
  parameter int unsigned ACC_W  = 20;     // accumulator          (signed)
  parameter int unsigned BIAS_W = 16;     // bias                 (signed)

  // ── Derived ─────────────────────────────────────────────────────────────────
  parameter int unsigned PROD_W = ACT_W + WGT_W;   // 16 - raw multiply width

endpackage
