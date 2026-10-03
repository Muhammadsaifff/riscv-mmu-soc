`timescale 1ns/1ps
module apb_sva(apb_if vif);
  default clocking cb @(posedge vif.clk); endclocking

  a_access_requires_select:
    assert property (vif.penable |-> vif.psel)
      else $error("APB: PENABLE asserted without PSEL");

  a_stable_setup_to_access:
    assert property (vif.psel && !vif.penable |=>
                     vif.psel && vif.penable &&
                     $stable(vif.paddr) && $stable(vif.pwrite) && $stable(vif.pwdata))
      else $error("APB: setup information changed before access");

  a_no_ready_without_access:
    assert property (vif.pready |-> vif.psel && vif.penable)
      else $error("APB: PREADY asserted outside access phase");
endmodule
