`timescale 1ns/1ps

module soc_full_uvm_top;
  import uvm_pkg::*;
  import vm_apb_pkg::*;
  import soc_full_uvm_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  apb_if apb(clk);
  vm_status_if status(clk);
  soc_full_if soc(clk);

  wire uart_tx;
  wire [15:0] gpio;

  Top #(
    .IMEM_INIT_PATH("test_program.dat"),
    .CLK_FREQ_HZ(50_000_000)
  ) dut (
    .clk(clk),
    .reset(~apb.reset_n),
    .psel(apb.psel),
    .penable(apb.penable),
    .pwrite(apb.pwrite),
    .paddr(apb.paddr),
    .pwdata(apb.pwdata),
    .prdata(apb.prdata),
    .pready(apb.pready),
    .uart_tx_o(uart_tx),
    .gpio(gpio),

    .dbg_i_va(status.i_va),
    .dbg_i_pa(status.i_pa),
    .dbg_d_va(status.d_va),
    .dbg_d_pa(status.d_pa),
    .dbg_i_valid(status.i_valid),
    .dbg_d_valid(status.d_valid),
    .dbg_d_write(status.d_write),
    .dbg_i_fault(status.i_fault),
    .dbg_d_fault(status.d_fault),
    .dbg_i_perm_fault(status.i_perm_fault),
    .dbg_d_perm_fault(status.d_perm_fault),
    .dbg_i_tlb_hit(status.i_tlb_hit),
    .dbg_d_tlb_hit(status.d_tlb_hit),
    .dbg_i_tlb_miss(status.i_tlb_miss),
    .dbg_d_tlb_miss(status.d_tlb_miss),
    .dbg_mmu_enable(status.mmu_enable),
    .dbg_uart_busy(),
    .dbg_d_write_commit(status.d_write_commit),
    .dbg_i_fault_sticky(status.i_fault_sticky),
    .dbg_d_fault_sticky(status.d_fault_sticky),
    .dbg_i_perm_sticky(status.i_perm_sticky),
    .dbg_d_perm_sticky(status.d_perm_sticky)
  );

  assign status.reset = ~apb.reset_n;

  // Full-SoC observation points.
  assign soc.reset          = ~apb.reset_n;
  assign soc.pc             = dut.RV32I_Logic.pc;
  assign soc.inst_raw       = dut.inst_raw;
  assign soc.inst           = dut.inst;
  assign soc.dmem_va        = dut.dmemAdrs;
  assign soc.dmem_pa        = dut.dmemAdrs_phys;
  assign soc.dmem_wdata     = dut.dmemDataStore;
  assign soc.dmem_rdata     = dut.dmemDataRead;
  assign soc.dmem_we_raw    = dut.dmemWE_raw;
  assign soc.dmem_we_safe   = dut.dmemWE_safe;
  assign soc.dmem_mode      = dut.dmemMode;

  assign soc.x0 = dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[0];
  assign soc.x1 = dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[1];
  assign soc.x2 = dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[2];
  assign soc.x3 = dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[3];
  assign soc.x4 = dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[4];
  assign soc.x5 = dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[5];
  assign soc.x6 = dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[6];
  assign soc.x7 = dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[7];

  // 0x1000 / 4 = word index 1024.
  assign soc.dmem_word_1000 = dut.dataMemory.mem[1024];

  assign soc.uart_busy = dut.uart_busy;
  assign soc.uart_tx   = uart_tx;
  assign soc.gpio      = gpio;

  apb_sva apb_chk(apb);
  vm_sva  vm_chk(status);

  initial begin
    apb.reset_n = 1'b0;
    apb.psel    = 1'b0;
    apb.penable = 1'b0;
    apb.pwrite  = 1'b0;
    apb.paddr   = 32'h0;
    apb.pwdata  = 32'h0;

    uvm_config_db#(virtual apb_if)::set(null, "", "vif", apb);
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.agent.*", "vif", apb);
    uvm_config_db#(virtual vm_status_if)::set(null, "uvm_test_top.env.vm_mon", "status_vif", status);
    uvm_config_db#(virtual soc_full_if)::set(null, "", "soc_vif", soc);

    run_test("soc_full_test");
  end
endmodule
