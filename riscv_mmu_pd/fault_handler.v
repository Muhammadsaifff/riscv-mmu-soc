// Sticky fault/status register block. Fault address is captured on first fault
// until software clears it through APB.
module fault_handler(
    input wire clk, reset,
    input wire i_fault, d_fault, i_perm_fault, d_perm_fault,
    input wire [31:0] fault_va,
    output reg i_fault_sticky, d_fault_sticky,
    output reg i_perm_sticky, d_perm_sticky,
    output reg [31:0] fault_addr,
    input wire clear_i, clear_d, clear_all
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            i_fault_sticky <= 1'b0; d_fault_sticky <= 1'b0;
            i_perm_sticky <= 1'b0; d_perm_sticky <= 1'b0;
            fault_addr <= 32'b0;
        end else begin
            if (clear_all || clear_i) begin i_fault_sticky <= 1'b0; i_perm_sticky <= 1'b0; end
            else if (i_fault) begin i_fault_sticky <= 1'b1; fault_addr <= fault_va; end
            if (clear_all || clear_d) begin d_fault_sticky <= 1'b0; d_perm_sticky <= 1'b0; end
            else if (d_fault) begin d_fault_sticky <= 1'b1; fault_addr <= fault_va; end
            if (!clear_all && !clear_i && i_perm_fault) i_perm_sticky <= 1'b1;
            if (!clear_all && !clear_d && d_perm_fault) d_perm_sticky <= 1'b1;
        end
    end
endmodule
