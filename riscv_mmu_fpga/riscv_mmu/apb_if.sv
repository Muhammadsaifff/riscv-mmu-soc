interface apb_if(input logic clk);
  logic reset_n;
  logic psel, penable, pwrite;
  logic [31:0] paddr, pwdata, prdata;
  logic pready;
  clocking master_cb @(posedge clk);
    output psel, penable, pwrite, paddr, pwdata;
    input prdata, pready;
  endclocking
endinterface
