`timescale 1ns/1ps
module mmu_uvm_top;
  import uvm_pkg::*;
  import mmu_uvm_pkg::*;

  logic clk=0;
  always #5 clk=~clk;

  mmu_if vif(clk);

  wire [19:0] req_vpn;
  wire [19:0] pt_ppn;
  wire [4:0]  pt_flags;
  wire refill_valid;
  wire [19:0] refill_vpn, refill_ppn;
  wire [4:0] refill_flags;

  page_table pt (
    .clk(clk), .reset(vif.reset),
    .lookup0_vpn(req_vpn), .lookup0_ppn(pt_ppn), .lookup0_flags(pt_flags),
    .lookup1_vpn(20'b0), .lookup1_ppn(), .lookup1_flags(),
    .cfg_we(vif.cfg_we), .cfg_index(vif.cfg_index),
    .cfg_ppn(vif.cfg_ppn), .cfg_flags(vif.cfg_flags)
  );

  mmu_sva sva(vif);

  mmu dut (
    .clk(clk), .reset(vif.reset), .enable(vif.enable),
    .access_valid(vif.access_valid),
    .access_write(vif.access_write),
    .access_exec(vif.access_exec),
    .virt_addr(vif.va),
    .phys_addr(vif.pa),
    .page_fault(vif.page_fault),
    .permission_fault(vif.permission_fault),
    .tlb_hit(vif.tlb_hit),
    .tlb_miss(vif.tlb_miss),
    .pt_lookup_vpn(req_vpn),
    .pt_ppn(pt_ppn),
    .pt_flags(pt_flags),
    .tlb_refill_valid(refill_valid),
    .tlb_refill_vpn(refill_vpn),
    .tlb_refill_ppn(refill_ppn),
    .tlb_refill_flags(refill_flags),
    .tlb_flush(vif.tlb_flush)
  );

  initial begin
    vif.reset = 1'b1;
    vif.enable = 1'b1;
    vif.cfg_we = 1'b0;
    vif.cfg_index = '0;
    vif.cfg_ppn = '0;
    vif.cfg_flags = '0;
    vif.tlb_flush = 1'b0;
    vif.access_valid = 1'b0;
    vif.access_write = 1'b0;
    vif.access_exec = 1'b0;
    vif.va = '0;

    repeat (4) @(posedge clk);
    vif.reset = 1'b0;
  end

  initial begin
    uvm_config_db#(virtual mmu_if)::set(null,"uvm_test_top.env.agent.*","vif",vif);
    wait(vif.reset === 1'b0);
    run_test("mmu_uvm_test");
  end
endmodule
