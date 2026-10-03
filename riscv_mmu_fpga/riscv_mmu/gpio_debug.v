module gpio_debug(
    input wire mmu_enable,
    input wire i_tlb_hit, d_tlb_hit,
    input wire i_fault, d_fault,
    input wire i_perm_fault, d_perm_fault,
    input wire [31:0] pc,
    output wire [15:0] gpio
);
    assign gpio[0] = mmu_enable;
    assign gpio[1] = i_tlb_hit;
    assign gpio[2] = d_tlb_hit;
    assign gpio[3] = i_fault;
    assign gpio[4] = d_fault;
    assign gpio[5] = i_perm_fault;
    assign gpio[6] = d_perm_fault;
    assign gpio[15:7] = pc[11:3];
endmodule
