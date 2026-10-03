`timescale 1ns/1ps
module mmu_uvm_top;
  import uvm_pkg::*; import mmu_uvm_pkg::*;
  bit clk=0; always #5 clk=~clk;
  mmu_if vif(clk);
  wire [19:0] req_vpn, pt_ppn; wire [4:0] pt_flags;
  wire refill; wire [19:0] rvpn,rppn; wire [4:0] rflags;
  page_table pt(.clk(clk),.reset(vif.reset),.lookup0_vpn(req_vpn),.lookup0_ppn(pt_ppn),.lookup0_flags(pt_flags),.lookup1_vpn(20'b0),.lookup1_ppn(),.lookup1_flags(),.cfg_we(vif.cfg_we),.cfg_index(vif.cfg_index),.cfg_ppn(vif.cfg_ppn),.cfg_flags(vif.cfg_flags));
  mmu dut(.clk(clk),.reset(vif.reset),.enable(1'b1),.access_valid(vif.access_valid),.access_write(vif.access_write),.access_exec(vif.access_exec),.virt_addr(vif.va),.phys_addr(vif.pa),.page_fault(vif.page_fault),.permission_fault(vif.permission_fault),.tlb_hit(vif.tlb_hit),.tlb_miss(vif.tlb_miss),.pt_lookup_vpn(req_vpn),.pt_ppn(pt_ppn),.pt_flags(pt_flags),.tlb_refill_valid(refill),.tlb_refill_vpn(rvpn),.tlb_refill_ppn(rppn),.tlb_refill_flags(rflags),.tlb_flush(1'b0));
  initial begin vif.reset=1; vif.cfg_we=0; vif.access_valid=0; vif.access_write=0; vif.access_exec=0; vif.va=0; vif.cfg_index=0; vif.cfg_ppn=0; vif.cfg_flags=0; repeat(3) @(posedge clk); vif.reset=0; uvm_config_db#(virtual mmu_if)::set(null,"uvm_test_top.env.agent.*","vif",vif); run_test("mmu_uvm_test"); end
endmodule
