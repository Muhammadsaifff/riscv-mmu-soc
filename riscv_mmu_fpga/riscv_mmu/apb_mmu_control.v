// APB4-style MMU control/status slave.
//
// Register map
// 0x00 CTRL   [0] MMU enable, [1] TLB flush (write-1 pulse)
// 0x04 PTBR   software-visible page-table base register
// 0x08 STATUS [0] I fault, [1] D fault, [2] I perm, [3] D perm,
//              [4] I TLB hit, [5] D TLB hit, [6] I TLB miss, [7] D TLB miss
//              [8] I sticky fault, [9] D sticky fault,
//              [10] I sticky perm, [11] D sticky perm
// 0x0C FAULT_VA captured faulting virtual address
// 0x10..0x4C PTE[i]: [19:0] PPN, [24:20] flags V,R,W,X,U
// 0x80 UART_TX write low byte
// 0x84 UART_STATUS [0] busy
module apb_mmu_control(
    input wire clk, reset,
    input wire psel, penable, pwrite,
    input wire [31:0] paddr, pwdata,
    output reg [31:0] prdata,
    output wire pready,
    output reg mmu_enable,
    output reg tlb_flush,
    output reg [31:0] ptbr,
    output reg pte_we,
    output reg [3:0] pte_index,
    output reg [19:0] pte_ppn,
    output reg [4:0] pte_flags,
    input wire i_fault, d_fault, i_perm_fault, d_perm_fault,
    input wire i_tlb_hit, d_tlb_hit, i_tlb_miss, d_tlb_miss,
    input wire i_fault_sticky, d_fault_sticky, i_perm_sticky, d_perm_sticky,
    input wire [31:0] fault_addr,
    output reg clear_i, clear_d, clear_all,
    output reg uart_we,
    output reg [7:0] uart_wdata,
    input wire uart_busy
);
    assign pready = psel && penable;

    wire pte_addr = (paddr[7:0] >= 8'h10) && (paddr[7:0] < 8'h50) && (paddr[1:0] == 2'b00);
    wire [3:0] decoded_pte_index = paddr[5:2] - 4'h4;

    always @(*) begin
        prdata = 32'h0;
        case (paddr[7:0])
            8'h00: prdata = {30'b0, 1'b0, mmu_enable};
            8'h04: prdata = ptbr;
            8'h08: prdata = {20'b0, d_perm_sticky, i_perm_sticky,
                              d_fault_sticky, i_fault_sticky,
                              d_tlb_miss, i_tlb_miss, d_tlb_hit, i_tlb_hit,
                              d_perm_fault, i_perm_fault, d_fault, i_fault};
            8'h0C: prdata = fault_addr;
            8'h84: prdata = {31'b0, uart_busy};
            default: begin
                // PTE readback is not retained in this compact APB block.
                // The programmed PTE values are observable through the MMU tests.
                prdata = 32'h0;
            end
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mmu_enable <= 1'b0;
            tlb_flush <= 1'b0;
            ptbr <= 32'h0000_0000;
            pte_we <= 1'b0;
            pte_index <= 4'h0;
            pte_ppn <= 20'h0;
            pte_flags <= 5'h0;
            clear_i <= 1'b0;
            clear_d <= 1'b0;
            clear_all <= 1'b0;
            uart_we <= 1'b0;
            uart_wdata <= 8'h00;
        end else begin
            tlb_flush <= 1'b0;
            clear_i <= 1'b0;
            clear_d <= 1'b0;
            clear_all <= 1'b0;
            uart_we <= 1'b0;
            pte_we <= 1'b0;

            if (psel && penable && pwrite) begin
                case (paddr[7:0])
                    8'h00: begin
                        mmu_enable <= pwdata[0];
                        if (pwdata[1]) tlb_flush <= 1'b1;
                    end
                    8'h04: ptbr <= pwdata;
                    8'h08: begin
                        clear_i <= pwdata[0];
                        clear_d <= pwdata[1];
                        clear_all <= pwdata[8];
                    end
                    8'h80: begin
                        uart_we <= 1'b1;
                        uart_wdata <= pwdata[7:0];
                    end
                    default: begin
                        if (pte_addr) begin
                            pte_we <= 1'b1;
                            pte_index <= decoded_pte_index;
                            pte_ppn <= pwdata[19:0];
                            pte_flags <= pwdata[24:20];
                        end
                    end
                endcase
            end
        end
    end
endmodule
