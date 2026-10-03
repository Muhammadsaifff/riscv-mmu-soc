`timescale 1ns/1ps
module uvm_top;
  import uvm_pkg::*;
  import vm_apb_pkg::*;

  bit clk=0;
  always #5 clk=~clk;

  apb_if apb(clk);
  vm_status_if status(clk);
  wire uart_tx;
  wire [15:0] gpio;

  Top #(.IMEM_INIT_PATH("test_program.dat"), .CLK_FREQ_HZ(50_000_000)) dut(
    .clk(clk), .reset(~apb.reset_n),
    .psel(apb.psel), .penable(apb.penable), .pwrite(apb.pwrite),
    .paddr(apb.paddr), .pwdata(apb.pwdata),
    .prdata(apb.prdata), .pready(apb.pready), .uart_tx_o(uart_tx), .gpio(gpio),
    .dbg_i_va(status.i_va), .dbg_i_pa(status.i_pa), .dbg_d_va(status.d_va), .dbg_d_pa(status.d_pa),
    .dbg_i_valid(status.i_valid), .dbg_d_valid(status.d_valid), .dbg_d_write(status.d_write),
    .dbg_i_fault(status.i_fault), .dbg_d_fault(status.d_fault),
    .dbg_i_perm_fault(status.i_perm_fault), .dbg_d_perm_fault(status.d_perm_fault),
    .dbg_i_tlb_hit(status.i_tlb_hit), .dbg_d_tlb_hit(status.d_tlb_hit),
    .dbg_i_tlb_miss(status.i_tlb_miss), .dbg_d_tlb_miss(status.d_tlb_miss),
    .dbg_mmu_enable(status.mmu_enable), .dbg_uart_busy(), .dbg_d_write_commit(status.d_write_commit), .dbg_i_fault_sticky(), .dbg_d_fault_sticky(), .dbg_i_perm_sticky(), .dbg_d_perm_sticky()
  );

  assign status.reset = ~apb.reset_n;
  vm_sva sva(status);

  // Hardware reset block running concurrently without blocking time 0 for UVM
  initial begin
    apb.reset_n = 0; apb.psel = 0; apb.penable = 0; apb.pwrite = 0;
    apb.paddr = 0; apb.pwdata = 0;
    repeat(3) @(posedge clk);
    apb.reset_n = 1;
  end

  // UVM execution block starting strictly at time 0
  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.agent.*", "vif", apb);
    uvm_config_db#(virtual vm_status_if)::set(null, "uvm_test_top.env.vm_mon", "status_vif", status);
    run_test("vm_apb_test");
  end
endmodule
