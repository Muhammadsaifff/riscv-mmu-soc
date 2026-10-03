// SystemVerilog assertions for the simplified VM subsystem.
module vm_sva(vm_status_if vif);
  default clocking cb @(posedge vif.clk); endclocking

  property i_offset_preserved;
    vif.mmu_enable && vif.i_valid && !vif.i_fault |-> (vif.i_pa[11:0] == vif.i_va[11:0]);
  endproperty
  a_i_offset_preserved: assert property(i_offset_preserved)
    else $error("I-MMU did not preserve page offset");

  property d_offset_preserved;
    vif.mmu_enable && vif.d_valid && !vif.d_fault |-> (vif.d_pa[11:0] == vif.d_va[11:0]);
  endproperty
  a_d_offset_preserved: assert property(d_offset_preserved)
    else $error("D-MMU did not preserve page offset");

  property fault_zeroes_pa_i;
    vif.i_fault |-> (vif.i_pa == 32'h0);
  endproperty
  a_fault_zeroes_pa_i: assert property(fault_zeroes_pa_i)
    else $error("I fault did not force safe PA");

  property fault_zeroes_pa_d;
    vif.d_fault |-> (vif.d_pa == 32'h0);
  endproperty
  a_fault_zeroes_pa_d: assert property(fault_zeroes_pa_d)
    else $error("D fault did not force safe PA");

  property miss_is_not_hit_i;
    vif.i_valid && vif.i_tlb_miss |-> !vif.i_tlb_hit;
  endproperty
  a_miss_not_hit_i: assert property(miss_is_not_hit_i)
    else $error("I-TLB reported hit and miss simultaneously");

  property faulting_store_is_blocked;
    vif.d_valid && vif.d_write && vif.d_fault |-> !vif.d_write_commit;
  endproperty
  a_faulting_store_is_blocked: assert property(faulting_store_is_blocked)
    else $error("Faulting store was not suppressed");

  property miss_is_not_hit_d;
    vif.d_valid && vif.d_tlb_miss |-> !vif.d_tlb_hit;
  endproperty
  a_miss_not_hit_d: assert property(miss_is_not_hit_d)
    else $error("D-TLB reported hit and miss simultaneously");
endmodule
