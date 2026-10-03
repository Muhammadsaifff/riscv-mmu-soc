`timescale 1ns/1ps
module vm_mmu_unit_tb;
  reg clk=0, reset=1;
  always #5 clk=~clk;

  reg cfg_we=0; reg [3:0] cfg_index=0; reg [19:0] cfg_ppn=0; reg [4:0] cfg_flags=0;
  reg i_valid, i_wr, i_ex; reg [31:0] i_va; wire [31:0] i_pa; wire i_fault,i_perm,i_hit,i_miss;
  wire [19:0] i_req; wire i_refill; wire [19:0] i_rvpn,i_rppn; wire [4:0] i_rf;
  wire [19:0] i_ppn, d_ppn; wire [4:0] i_flags, d_flags;
  reg d_valid,d_wr,d_ex; reg [31:0] d_va; wire [31:0] d_pa; wire d_fault,d_perm,d_hit,d_miss;
  wire [19:0] d_req; wire d_refill; wire [19:0] d_rvpn,d_rppn; wire [4:0] d_rf;
  
  page_table pt(.clk(clk),.reset(reset),.lookup0_vpn(i_req),.lookup0_ppn(i_ppn),.lookup0_flags(i_flags),
                .lookup1_vpn(d_req),.lookup1_ppn(d_ppn),.lookup1_flags(d_flags),
                .cfg_we(cfg_we),.cfg_index(cfg_index),.cfg_ppn(cfg_ppn),.cfg_flags(cfg_flags));
                
  mmu im(.clk(clk),.reset(reset),.enable(1'b1),.access_valid(i_valid),.access_write(i_wr),.access_exec(i_ex),
         .virt_addr(i_va),.phys_addr(i_pa),.page_fault(i_fault),.permission_fault(i_perm),.tlb_hit(i_hit),.tlb_miss(i_miss),
         .pt_lookup_vpn(i_req),.pt_ppn(i_ppn),.pt_flags(i_flags),.tlb_refill_valid(i_refill),.tlb_refill_vpn(i_rvpn),
         .tlb_refill_ppn(i_rppn),.tlb_refill_flags(i_rf),.tlb_flush(1'b0));

  mmu dm(.clk(clk),.reset(reset),.enable(1'b1),.access_valid(d_valid),.access_write(d_wr),.access_exec(d_ex),
         .virt_addr(d_va),.phys_addr(d_pa),.page_fault(d_fault),.permission_fault(d_perm),.tlb_hit(d_hit),.tlb_miss(d_miss),
         .pt_lookup_vpn(d_req),.pt_ppn(d_ppn),.pt_flags(d_flags),.tlb_refill_valid(d_refill),.tlb_refill_vpn(d_rvpn),
         .tlb_refill_ppn(d_rppn),.tlb_refill_flags(d_rf),.tlb_flush(1'b0));

  task cfg(input [3:0] idx,input [19:0] ppn,input [4:0] fl);
    begin 
      @(negedge clk); 
      cfg_index=idx; cfg_ppn=ppn; cfg_flags=fl; cfg_we=1; 
      $display("[%0t] CONFIG PTE: Index=%0d, PPN=%05x, Flags=%05b", $time, idx, ppn, fl);
      @(negedge clk); 
      cfg_we=0; 
    end
  endtask
  
  task check(input condition, input [255:0] msg);
    begin 
      if(!condition) begin 
        $display("[%0t] FAIL: %0s", $time, msg); 
        $fatal; 
      end else begin
        $display("[%0t] PASS: %0s\n", $time, msg); 
      end
    end
  endtask

  initial begin
    $timeformat(-9, 0, " ns", 10);
    $display("==================================================");
    $display("   STARTING MMU UNIT TESTS");
    $display("==================================================");
    i_valid=0; i_wr=0; i_ex=0; i_va=0; d_valid=0; d_wr=0; d_ex=0; d_va=0;
    
    repeat(2) @(negedge clk); reset=0;
    $display("[%0t] System Reset Deasserted\n", $time);
    
    // VPN 1 -> PPN 2, RWX valid.
    cfg(4'h1, 20'h00002, 5'b01111);
    
    // First instruction fetch from VPN1 must be a PT hit but TLB miss.
    @(negedge clk); i_va=32'h00001034; i_valid=1; i_ex=1;
    #1; 
    $display("[%0t] I-MMU Fetch: VA=%08x | Result PA=%08x", $time, i_va, i_pa);
    $display("            Status: Miss=%0b, Hit=%0b, Fault=%0b", i_miss, i_hit, i_fault);
    check(i_miss && !i_fault && i_pa==32'h00002034, "I-MMU page-table translation");
    
    @(posedge clk); #1; 
    $display("[%0t] I-MMU Refill Check: Hit=%0b", $time, i_hit);
    check(i_hit, "I-TLB refill then hit");
    i_valid=0; 
    
    // D-side write to same VPN should hit its independently refilled TLB.
    @(negedge clk); d_va=32'h00001044; d_valid=1; d_wr=1; d_ex=0;
    #1; 
    $display("[%0t] D-MMU Write: VA=%08x | Result PA=%08x", $time, d_va, d_pa);
    $display("            Status: Miss=%0b, Hit=%0b, Fault=%0b", d_miss, d_hit, d_fault);
    check(d_miss && !d_fault && d_pa==32'h00002044, "D-MMU translation and refill");
    
    @(posedge clk); #1; 
    $display("[%0t] D-MMU Refill Check: Hit=%0b", $time, d_hit);
    check(d_hit, "D-TLB refill then hit");
    d_valid=0; 
    
    // Invalid VPN must page fault.
    @(negedge clk); i_va=32'h0000F034; i_valid=1; i_ex=1;
    #1; 
    $display("[%0t] I-MMU Invalid Fetch: VA=%08x", $time, i_va);
    $display("            Status: Fault=%0b, Perm_Fault=%0b", i_fault, i_perm);
    check(i_fault && !i_perm, "invalid PTE page fault");
    i_valid=0; 
    
    // Read-only page: data write must permission fault.
    cfg(4'h2, 20'h00003, 5'b10011); // V,R only
    @(negedge clk); d_va=32'h00002008; d_valid=1; d_wr=1; d_ex=0;
    #1; 
    $display("[%0t] D-MMU RO Write: VA=%08x", $time, d_va);
    $display("            Status: Fault=%0b, Perm_Fault=%0b", d_fault, d_perm);
    check(d_fault && d_perm, "write permission fault");
    d_valid=0; 
    
    $display("==================================================");
    $display("[%0t] ALL MMU DIRECTED TESTS PASSED", $time);
    $display("==================================================");
    $finish;
  end
endmodule
