// Complete RISC-V RV32I + simplified virtual-memory SoC.
module Top #(
    parameter IMEM_INIT_PATH="imem.dat",
    parameter CLK_FREQ_HZ=50_000_000
)(
    input wire clk,
    input wire reset,

    input wire psel,
    input wire penable,
    input wire pwrite,
    input wire [31:0] paddr,
    input wire [31:0] pwdata,

    output wire [31:0] prdata,
    output wire pready,
    output wire uart_tx_o,
    output wire [15:0] gpio,

    output wire [31:0] dbg_i_va,
    output wire [31:0] dbg_i_pa,
    output wire [31:0] dbg_d_va,
    output wire [31:0] dbg_d_pa,

    output wire dbg_i_valid,
    output wire dbg_d_valid,
    output wire dbg_d_write,

    output wire dbg_i_fault,
    output wire dbg_d_fault,

    output wire dbg_i_perm_fault,
    output wire dbg_d_perm_fault,

    output wire dbg_i_tlb_hit,
    output wire dbg_d_tlb_hit,

    output wire dbg_i_tlb_miss,
    output wire dbg_d_tlb_miss,

    output wire dbg_mmu_enable,
    output wire dbg_uart_busy,
    output wire dbg_d_write_commit,

    output wire dbg_i_fault_sticky,
    output wire dbg_d_fault_sticky,

    output wire dbg_i_perm_sticky,
    output wire dbg_d_perm_sticky

`ifdef USE_POWER_PINS
    ,inout wire vccd1
    ,inout wire vssd1
`endif
);

    wire [31:0] pc, inst_raw, inst;
    wire [31:0] dmemDataStore, dmemDataRead, dmemAdrs;
    wire [2:0] dmemMode;
    wire dmemWE_raw;

    wire [31:0] pc_phys, dmemAdrs_phys;

    wire i_page_fault, d_page_fault;
    wire i_perm_fault, d_perm_fault;

    wire dmem_clear_active;
    wire cpu_reset;

    // NOTE:
    // vccd1/vssd1 are top-level ports when USE_POWER_PINS is enabled.
    // Do NOT redeclare them as local wires here. They must propagate
    // from SoC_Hardened -> Top -> dmem -> SRAM macro pins.

    assign cpu_reset = reset || dmem_clear_active;

    wire i_tlb_hit, d_tlb_hit;
    wire i_tlb_miss, d_tlb_miss;

    wire mmu_enable;

    wire i_access_valid = 1'b1;
    wire d_access_valid = dmemWE_raw || (inst[6:0] == 7'b0000011);
    wire d_access_write = dmemWE_raw;

    wire [19:0] i_vpn, d_vpn;
    wire [19:0] i_pt_ppn, d_pt_ppn;
    wire [4:0] i_pt_flags, d_pt_flags;

    wire i_refill, d_refill;
    wire [19:0] i_refill_vpn, d_refill_vpn;
    wire [19:0] i_refill_ppn, d_refill_ppn;
    wire [4:0] i_refill_flags, d_refill_flags;

    wire tlb_flush;
    wire [31:0] ptbr;

    wire pte_we;
    wire [3:0] pte_index;
    wire [19:0] pte_ppn;
    wire [4:0] pte_flags;

    wire clear_i, clear_d, clear_all;

    wire uart_we;
    wire [7:0] uart_wdata;
    wire uart_busy;

    wire i_fault_sticky, d_fault_sticky;
    wire i_perm_sticky, d_perm_sticky;

    wire [31:0] fault_addr;


    Single_Cycle_RV32I RV32I_Logic(
        .clk(clk),
        .reset(cpu_reset),
        .inst(inst),
        .pc(pc),
        .dmemWE(dmemWE_raw),
        .dmemMode(dmemMode),
        .dmemAdrs(dmemAdrs),
        .dmemDataRead(dmemDataRead),
        .dmemDataStore(dmemDataStore)
    );


    assign inst = (i_page_fault || i_perm_fault) ?
                  32'h00000013 : inst_raw;


    mmu instruction_mmu(
        .clk(clk),
        .reset(reset),
        .enable(mmu_enable),
        .access_valid(i_access_valid),
        .access_write(1'b0),
        .access_exec(1'b1),
        .virt_addr(pc),
        .phys_addr(pc_phys),
        .page_fault(i_page_fault),
        .permission_fault(i_perm_fault),
        .tlb_hit(i_tlb_hit),
        .tlb_miss(i_tlb_miss),
        .pt_lookup_vpn(i_vpn),
        .pt_ppn(i_pt_ppn),
        .pt_flags(i_pt_flags),
        .tlb_refill_valid(i_refill),
        .tlb_refill_vpn(i_refill_vpn),
        .tlb_refill_ppn(i_refill_ppn),
        .tlb_refill_flags(i_refill_flags),
        .tlb_flush(tlb_flush)
    );


    mmu data_mmu(
        .clk(clk),
        .reset(reset),
        .enable(mmu_enable),
        .access_valid(d_access_valid),
        .access_write(d_access_write),
        .access_exec(1'b0),
        .virt_addr(dmemAdrs),
        .phys_addr(dmemAdrs_phys),
        .page_fault(d_page_fault),
        .permission_fault(d_perm_fault),
        .tlb_hit(d_tlb_hit),
        .tlb_miss(d_tlb_miss),
        .pt_lookup_vpn(d_vpn),
        .pt_ppn(d_pt_ppn),
        .pt_flags(d_pt_flags),
        .tlb_refill_valid(d_refill),
        .tlb_refill_vpn(d_refill_vpn),
        .tlb_refill_ppn(d_refill_ppn),
        .tlb_refill_flags(d_refill_flags),
        .tlb_flush(tlb_flush)
    );


    page_table u_page_table(
        .clk(clk),
        .reset(reset),
        .lookup0_vpn(i_vpn),
        .lookup0_ppn(i_pt_ppn),
        .lookup0_flags(i_pt_flags),
        .lookup1_vpn(d_vpn),
        .lookup1_ppn(d_pt_ppn),
        .lookup1_flags(d_pt_flags),
        .cfg_we(pte_we),
        .cfg_index(pte_index),
        .cfg_ppn(pte_ppn),
        .cfg_flags(pte_flags)
    );


    wire dmemWE_safe =
        dmemWE_raw && !d_page_fault && !d_perm_fault;


    dmem #(.MEM_BYTES(4096)) dataMemory(
        .a(dmemAdrs_phys),
        .rd(dmemDataRead),
        .wd(dmemDataStore),
        .clk(clk),
        .we(dmemWE_safe),
        .mode(dmemMode),
        .reset(reset),
        .clear_active(dmem_clear_active)
`ifdef USE_POWER_PINS
        ,.vccd1(vccd1)
        ,.vssd1(vssd1)
`endif
    );


    imem #(
        .MEM_BYTES(4096),
        .INITIAL_DATA_PATH(IMEM_INIT_PATH)
    ) instrMemory(
        .a(pc_phys),
        .rd(inst_raw)
    );


    fault_handler u_faults(
        .clk(clk),
        .reset(reset),
        .i_fault(i_page_fault),
        .d_fault(d_page_fault),
        .i_perm_fault(i_perm_fault),
        .d_perm_fault(d_perm_fault),
        .fault_va(d_page_fault ? dmemAdrs : pc),
        .i_fault_sticky(i_fault_sticky),
        .d_fault_sticky(d_fault_sticky),
        .i_perm_sticky(i_perm_sticky),
        .d_perm_sticky(d_perm_sticky),
        .fault_addr(fault_addr),
        .clear_i(clear_i),
        .clear_d(clear_d),
        .clear_all(clear_all)
    );


    apb_mmu_control u_apb_ctrl(
        .clk(clk),
        .reset(reset),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .mmu_enable(mmu_enable),
        .tlb_flush(tlb_flush),
        .ptbr(ptbr),
        .pte_we(pte_we),
        .pte_index(pte_index),
        .pte_ppn(pte_ppn),
        .pte_flags(pte_flags),
        .i_fault(i_page_fault),
        .d_fault(d_page_fault),
        .i_perm_fault(i_perm_fault),
        .d_perm_fault(d_perm_fault),
        .i_tlb_hit(i_tlb_hit),
        .d_tlb_hit(d_tlb_hit),
        .i_tlb_miss(i_tlb_miss),
        .d_tlb_miss(d_tlb_miss),
        .i_fault_sticky(i_fault_sticky),
        .d_fault_sticky(d_fault_sticky),
        .i_perm_sticky(i_perm_sticky),
        .d_perm_sticky(d_perm_sticky),
        .fault_addr(fault_addr),
        .clear_i(clear_i),
        .clear_d(clear_d),
        .clear_all(clear_all),
        .uart_we(uart_we),
        .uart_wdata(uart_wdata),
        .uart_busy(uart_busy)
    );


    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD(115200)
    ) u_uart(
        .clk(clk),
        .reset(reset),
        .start(uart_we),
        .data(uart_wdata),
        .tx(uart_tx_o),
        .busy(uart_busy)
    );


    gpio_debug u_gpio(
        .mmu_enable(mmu_enable),
        .i_tlb_hit(i_tlb_hit),
        .d_tlb_hit(d_tlb_hit),
        .i_fault(i_page_fault),
        .d_fault(d_page_fault),
        .i_perm_fault(i_perm_fault),
        .d_perm_fault(d_perm_fault),
        .pc(pc),
        .gpio(gpio)
    );


    assign dbg_i_va = pc;
    assign dbg_i_pa = pc_phys;
    assign dbg_d_va = dmemAdrs;
    assign dbg_d_pa = dmemAdrs_phys;

    assign dbg_i_valid = i_access_valid;
    assign dbg_d_valid = d_access_valid;
    assign dbg_d_write = d_access_write;

    assign dbg_i_fault = i_page_fault;
    assign dbg_d_fault = d_page_fault;

    assign dbg_i_perm_fault = i_perm_fault;
    assign dbg_d_perm_fault = d_perm_fault;

    assign dbg_i_tlb_hit = i_tlb_hit;
    assign dbg_d_tlb_hit = d_tlb_hit;

    assign dbg_i_tlb_miss = i_tlb_miss;
    assign dbg_d_tlb_miss = d_tlb_miss;

    assign dbg_mmu_enable = mmu_enable;
    assign dbg_uart_busy = uart_busy;

    assign dbg_d_write_commit = dmemWE_safe;

    assign dbg_i_fault_sticky = i_fault_sticky;
    assign dbg_d_fault_sticky = d_fault_sticky;

    assign dbg_i_perm_sticky = i_perm_sticky;
    assign dbg_d_perm_sticky = d_perm_sticky;

endmodule
