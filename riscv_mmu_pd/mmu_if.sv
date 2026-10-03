interface mmu_if(input logic clk);
  logic reset;
  logic cfg_we;
  logic [3:0] cfg_index;
  logic [19:0] cfg_ppn;
  logic [4:0] cfg_flags;
  logic access_valid, access_write, access_exec;
  logic [31:0] va;
  logic [31:0] pa;
  logic page_fault, permission_fault, tlb_hit, tlb_miss;
endinterface
