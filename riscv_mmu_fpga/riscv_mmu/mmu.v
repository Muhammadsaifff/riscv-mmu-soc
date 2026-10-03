// Simplified Sv32-style VA->PA translator for a teaching SoC.
// 4-KiB pages: VPN=VA[31:12], offset=VA[11:0].
// On a TLB miss the supplied page-table PTE is used immediately and refilled
// into the TLB on the next clock. Invalid or permission-denied accesses fault.
module mmu(
    input wire clk, reset,
    input wire enable,
    input wire access_valid,
    input wire access_write,
    input wire access_exec,
    input wire [31:0] virt_addr,
    output reg [31:0] phys_addr,
    output reg page_fault,
    output reg permission_fault,
    output wire tlb_hit,
    output reg tlb_miss,
    output wire [19:0] pt_lookup_vpn,
    input wire [19:0] pt_ppn,
    input wire [4:0] pt_flags,
    output reg tlb_refill_valid,
    output reg [19:0] tlb_refill_vpn,
    output reg [19:0] tlb_refill_ppn,
    output reg [4:0] tlb_refill_flags,
    input wire tlb_flush
);
    wire [19:0] vpn = virt_addr[31:12];
    wire [11:0] offset = virt_addr[11:0];
    wire [19:0] tlb_ppn;
    wire [4:0] tlb_flags;

    assign pt_lookup_vpn = vpn;

    tlb u_tlb(
        .clk(clk), .reset(reset),
        .lookup_vpn(vpn), .hit(tlb_hit),
        .lookup_ppn(tlb_ppn), .lookup_flags(tlb_flags),
        .refill_valid(tlb_refill_valid), .refill_vpn(tlb_refill_vpn),
        .refill_ppn(tlb_refill_ppn), .refill_flags(tlb_refill_flags),
        .flush(tlb_flush)
    );

    function allowed;
        input [4:0] f;
        input wr, ex;
        begin
            if (!f[0]) allowed = 1'b0;
            else if (ex) allowed = f[3];
            else if (wr) allowed = f[2];
            else allowed = f[1];
        end
    endfunction

    always @(*) begin
        phys_addr = virt_addr;
        page_fault = 1'b0;
        permission_fault = 1'b0;
        tlb_miss = 1'b0;
        tlb_refill_valid = 1'b0;
        tlb_refill_vpn = vpn;
        tlb_refill_ppn = pt_ppn;
        tlb_refill_flags = pt_flags;

        if (access_valid) begin
            if (!enable) begin
                phys_addr = virt_addr;
            end else if (tlb_hit) begin
                if (!allowed(tlb_flags, access_write, access_exec)) begin
                    page_fault = 1'b1;
                    permission_fault = 1'b1;
                    phys_addr = 32'b0;
                end else begin
                    phys_addr = {tlb_ppn, offset};
                end
            end else begin
                tlb_miss = 1'b1;
                if (!pt_flags[0]) begin
                    page_fault = 1'b1;
                    phys_addr = 32'b0;
                end else if (!allowed(pt_flags, access_write, access_exec)) begin
                    page_fault = 1'b1;
                    permission_fault = 1'b1;
                    phys_addr = 32'b0;
                end else begin
                    phys_addr = {pt_ppn, offset};
                    tlb_refill_valid = 1'b1;
                end
            end
        end
    end
endmodule
