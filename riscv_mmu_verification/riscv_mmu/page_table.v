// 16-entry software-visible page table with two combinational read ports.
// PTE format: [19:0] PPN, [4:0] flags = V,R,W,X,U.
module page_table #(parameter ENTRIES=16)(
    input wire clk, reset,
    input wire [19:0] lookup0_vpn,
    output reg [19:0] lookup0_ppn,
    output reg [4:0] lookup0_flags,
    input wire [19:0] lookup1_vpn,
    output reg [19:0] lookup1_ppn,
    output reg [4:0] lookup1_flags,
    input wire cfg_we,
    input wire [3:0] cfg_index,
    input wire [19:0] cfg_ppn,
    input wire [4:0] cfg_flags
);
    reg [19:0] ppn [0:ENTRIES-1];
    reg [4:0] flags [0:ENTRIES-1];
    integer i;

    always @(*) begin
        lookup0_ppn = ppn[lookup0_vpn[3:0]];
        lookup0_flags = flags[lookup0_vpn[3:0]];
        lookup1_ppn = ppn[lookup1_vpn[3:0]];
        lookup1_flags = flags[lookup1_vpn[3:0]];
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i=0; i<ENTRIES; i=i+1) begin
                ppn[i] <= 20'b0;
                flags[i] <= 5'b0;
            end
            ppn[0] <= 20'h00000;
            flags[0] <= 5'b01111; // V,R,W,X
        end else if (cfg_we) begin
            ppn[cfg_index] <= cfg_ppn;
            flags[cfg_index] <= cfg_flags;
        end
    end
endmodule
