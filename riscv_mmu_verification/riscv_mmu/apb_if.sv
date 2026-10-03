`timescale 1ns/1ps
interface apb_if(input logic clk);
  logic reset_n;
  logic psel;
  logic penable;
  logic pwrite;
  logic [31:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic pready;

  clocking master_cb @(posedge clk);
    default input #1step output #0;
    output psel, penable, pwrite, paddr, pwdata;
    input prdata, pready;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step output #0;
    input reset_n, psel, penable, pwrite, paddr, pwdata, prdata, pready;
  endclocking
endinterface
