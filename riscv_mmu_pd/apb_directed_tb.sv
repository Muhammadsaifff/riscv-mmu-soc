`timescale 1ns/1ps
module apb_directed_tb;
  reg clk=0, reset=1; always #5 clk=~clk;
  reg psel=0, penable=0, pwrite=0; reg [31:0] paddr=0,pwdata=0; wire [31:0] prdata; wire pready; wire uart_tx; wire [15:0] gpio;
  Top #(.IMEM_INIT_PATH("sim/test_program.dat")) dut(
    .clk(clk),.reset(reset),.psel(psel),.penable(penable),.pwrite(pwrite),.paddr(paddr),.pwdata(pwdata),
    .prdata(prdata),.pready(pready),.uart_tx_o(uart_tx),.gpio(gpio));

  task apb_write(input [31:0] addr,input [31:0] data);
    begin
      @(negedge clk); paddr=addr; pwdata=data; pwrite=1; psel=1; penable=0;
      @(negedge clk); penable=1;
      @(posedge clk); #1; if(!pready) $fatal("APB write not ready");
      @(negedge clk); psel=0; penable=0; pwrite=0;
    end
  endtask
  task apb_read(input [31:0] addr,input [31:0] expected,input [255:0] msg);
    begin
      @(negedge clk); paddr=addr; pwrite=0; psel=1; penable=0;
      @(negedge clk); penable=1;
      @(posedge clk); #1; if(!pready) $fatal("APB read not ready");
      if(prdata !== expected) begin $display("FAIL %0s got=%h exp=%h",msg,prdata,expected); $fatal; end
      else $display("PASS %0s",msg);
      @(negedge clk); psel=0; penable=0;
    end
  endtask
  initial begin
    repeat(2) @(negedge clk); reset=0;
    apb_read(32'h04,32'h0,"PTBR reset");
    apb_write(32'h04,32'h00123000);
    apb_read(32'h04,32'h00123000,"PTBR write/read");
    apb_write(32'h00,32'h0);
    apb_read(32'h00,32'h0,"MMU disable");
    apb_write(32'h00,32'h3);
    apb_read(32'h00,32'h1,"MMU enable");
    apb_write(32'h80,32'h00000056);
    $display("APB DIRECTED TEST PASSED");
    $finish;
  end
endmodule
