`timescale 1ns/1ps
interface vm_status_if(input logic clk);
  logic reset;
  logic mmu_enable;
  logic [31:0] i_va, i_pa;
  logic [31:0] d_va, d_pa;
  logic i_valid, d_valid, d_write, d_write_commit;
  logic i_fault, d_fault, i_perm_fault, d_perm_fault;
  logic i_tlb_hit, d_tlb_hit, i_tlb_miss, d_tlb_miss;
  logic i_fault_sticky, d_fault_sticky;
  logic i_perm_sticky, d_perm_sticky;

  clocking mon_cb @(posedge clk);
    default input #1step output #0;
    input reset, mmu_enable;
    input i_va, i_pa, d_va, d_pa;
    input i_valid, d_valid, d_write, d_write_commit;
    input i_fault, d_fault, i_perm_fault, d_perm_fault;
    input i_tlb_hit, d_tlb_hit, i_tlb_miss, d_tlb_miss;
    input i_fault_sticky, d_fault_sticky, i_perm_sticky, d_perm_sticky;
  endclocking
endinterface
