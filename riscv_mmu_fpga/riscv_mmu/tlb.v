module tlb #(parameter ENTRIES=4)(
    input wire clk, reset,
    input wire [19:0] lookup_vpn,
    output reg hit,
    output reg [19:0] lookup_ppn,
    output reg [4:0] lookup_flags,
    input wire refill_valid,
    input wire [19:0] refill_vpn,
    input wire [19:0] refill_ppn,
    input wire [4:0] refill_flags,
    input wire flush
);

    reg valid [0:ENTRIES-1];
    reg [19:0] vpn [0:ENTRIES-1];
    reg [19:0] ppn [0:ENTRIES-1];
    reg [4:0] flags [0:ENTRIES-1];

    integer i;

    wire [1:0] index;
    wire [1:0] refill_index;

    assign index = lookup_vpn[1:0];
    assign refill_index = refill_vpn[1:0];

    always @(*) begin
        hit = valid[index] && (vpn[index] == lookup_vpn);
        lookup_ppn = ppn[index];
        lookup_flags = flags[index];
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid[i] <= 1'b0;
                vpn[i] <= 20'b0;
                ppn[i] <= 20'b0;
                flags[i] <= 5'b0;
            end
        end
        else if (flush) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid[i] <= 1'b0;
            end
        end
        else if (refill_valid) begin
            valid[refill_index] <= 1'b1;
            vpn[refill_index] <= refill_vpn;
            ppn[refill_index] <= refill_ppn;
            flags[refill_index] <= refill_flags;
        end
    end

endmodule


