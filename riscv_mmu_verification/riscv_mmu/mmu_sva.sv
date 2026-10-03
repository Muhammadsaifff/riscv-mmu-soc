`timescale 1ns/1ps
module vm_sva(vm_status_if vif);
  default clocking cb @(negedge vif.clk); endclocking

  a_hit_miss_exclusive:
    assert property (vif.i_valid |-> !(vif.i_tlb_hit && vif.i_tlb_miss))
      else $error("MMU: I-TLB hit and miss both asserted");
  a_d_hit_miss_exclusive:
    assert property (vif.d_valid |-> !(vif.d_tlb_hit && vif.d_tlb_miss))
      else $error("MMU: D-TLB hit and miss both asserted");

  a_i_fault_safe_pa:
    assert property (vif.i_valid && vif.i_fault |-> vif.i_pa == 32'h0)
      else $error("MMU: I-side fault did not force PA=0");
  a_d_fault_safe_pa:
    assert property (vif.d_valid && vif.d_fault |-> vif.d_pa == 32'h0)
      else $error("MMU: D-side fault did not force PA=0");

  a_disabled_i_bypass:
    assert property (vif.i_valid && !vif.mmu_enable |->
                     !vif.i_fault && !vif.i_perm_fault && vif.i_pa == vif.i_va)
      else $error("MMU: disabled I-side bypass failed");
  a_disabled_d_bypass:
    assert property (vif.d_valid && !vif.mmu_enable |->
                     !vif.d_fault && !vif.d_perm_fault && vif.d_pa == vif.d_va)
      else $error("MMU: disabled D-side bypass failed");

  a_i_offset_preserved:
    assert property (vif.i_valid && vif.mmu_enable && !vif.i_fault |->
                     vif.i_pa[11:0] == vif.i_va[11:0])
      else $error("MMU: I-side page offset not preserved");
  a_d_offset_preserved:
    assert property (vif.d_valid && vif.mmu_enable && !vif.d_fault |->
                     vif.d_pa[11:0] == vif.d_va[11:0])
      else $error("MMU: D-side page offset not preserved");

  a_fault_blocks_store:
    assert property (vif.d_valid && vif.d_write && vif.d_fault |-> !vif.d_write_commit)
      else $error("MMU: faulting store was committed");
endmodule
