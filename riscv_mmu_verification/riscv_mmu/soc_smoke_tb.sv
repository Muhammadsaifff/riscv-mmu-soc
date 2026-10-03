`timescale 1ns/1ps
module soc_smoke_tb;
  reg clk=0, reset=1;
  always #5 clk=~clk;
  wire [31:0] prdata; wire pready; wire uart_tx; wire [15:0] gpio;
  Top #(.IMEM_INIT_PATH("test_program.dat"), .CLK_FREQ_HZ(50_000_000)) dut(
    .clk(clk),.reset(reset),.psel(1'b0),.penable(1'b0),.pwrite(1'b0),.paddr(32'b0),.pwdata(32'b0),
    .prdata(prdata),.pready(pready),.uart_tx_o(uart_tx),.gpio(gpio));
  initial begin
    repeat(2) @(negedge clk); reset=0;
    repeat(12) @(posedge clk);
    if (dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[1] !== 32'd10) $fatal("x1 mismatch");
    if (dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[2] !== 32'd20) $fatal("x2 mismatch");
    if (dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[3] !== 32'd30) $fatal("x3 mismatch");
    if (dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[4] !== 32'd20) $fatal("x4 mismatch");
    if (dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[5] !== 32'd42) $fatal("x5 mismatch");
    if (dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[7] !== 32'd42) $fatal("x7 load mismatch");
    if (dut.RV32I_Logic.Single_Cycle_Datapath.regFILE.x[0] !== 32'd0) $fatal("x0 mismatch");
    $display("RV32I + VM SoC SMOKE TEST PASSED");
    $finish;
  end
endmodule
