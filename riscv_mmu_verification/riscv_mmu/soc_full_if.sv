`timescale 1ns/1ps

// Full-SoC verification interface.
// It exposes only verification/debug information; it does not change DUT behavior.
interface soc_full_if(input logic clk);
  logic reset;

  // CPU / instruction path
  logic [31:0] pc;
  logic [31:0] inst_raw;
  logic [31:0] inst;

  // Data-memory path
  logic [31:0] dmem_va;
  logic [31:0] dmem_pa;
  logic [31:0] dmem_wdata;
  logic [31:0] dmem_rdata;
  logic        dmem_we_raw;
  logic        dmem_we_safe;
  logic [2:0]  dmem_mode;

  // Selected register-file state
  logic [31:0] x1;
  logic [31:0] x2;
  logic [31:0] x3;
  logic [31:0] x4;
  logic [31:0] x5;
  logic [31:0] x6;
  logic [31:0] x7;
  logic [31:0] x0;

  // Data-memory contents at the address used by test_program.dat.
  logic [31:0] dmem_word_1000;

  // UART / GPIO
  logic        uart_busy;
  logic        uart_tx;
  logic [15:0] gpio;

  clocking cb @(posedge clk);
    default input #1step output #0;
    input reset;
    input pc, inst_raw, inst;
    input dmem_va, dmem_pa, dmem_wdata, dmem_rdata;
    input dmem_we_raw, dmem_we_safe, dmem_mode;
    input x0, x1, x2, x3, x4, x5, x6, x7;
    input dmem_word_1000;
    input uart_busy, uart_tx, gpio;
  endclocking
endinterface
