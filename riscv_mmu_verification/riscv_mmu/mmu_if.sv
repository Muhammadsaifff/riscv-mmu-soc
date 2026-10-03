interface mmu_if(input logic clk);
  logic reset;
  logic enable;

  logic cfg_we;
  logic [3:0] cfg_index;
  logic [19:0] cfg_ppn;
  logic [4:0] cfg_flags;
  logic tlb_flush;

  logic access_valid;
  logic access_write;
  logic access_exec;
  logic [31:0] va;

  logic [31:0] pa;
  logic page_fault;
  logic permission_fault;
  logic tlb_hit;
  logic tlb_miss;

  clocking drv_cb @(negedge clk);
    output enable, cfg_we, cfg_index, cfg_ppn, cfg_flags, tlb_flush;
    output access_valid, access_write, access_exec, va;
    input pa, page_fault, permission_fault, tlb_hit, tlb_miss;
  endclocking

  clocking mon_cb @(posedge clk);
    input reset, enable;
    input cfg_we, cfg_index, cfg_ppn, cfg_flags, tlb_flush;
    input access_valid, access_write, access_exec, va;
    input pa, page_fault, permission_fault, tlb_hit, tlb_miss;
  endclocking
endinterface
