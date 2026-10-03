// 4-KiB byte-addressable data SRAM model.
// mode encoding preserved from the original core:
// 000=LW/SW, 001=LHU/SH, 101=LH, 010=LBU/SB, 110=LB.
module dmem #(parameter MEM_BYTES=4096)(
    input wire [31:0] a,
    output reg [31:0] rd,
    input wire [31:0] wd,
    input wire clk,
    input wire we,
    input wire [2:0] mode,
    input wire reset
);
    reg [7:0] mem [0:MEM_BYTES-1];
    integer i;
    wire addr_ok = (a < MEM_BYTES);

    initial begin
        for (i=0; i<MEM_BYTES; i=i+1) mem[i] = 8'h00;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i=0; i<MEM_BYTES; i=i+1) mem[i] <= 8'h00;
        end else if (we && addr_ok) begin
            case (mode)
                3'b010, 3'b110: mem[a] <= wd[7:0];
                3'b001, 3'b101: begin
                    if (a+1 < MEM_BYTES) begin
                        mem[a]   <= wd[7:0];
                        mem[a+1] <= wd[15:8];
                    end
                end
                default: begin
                    if (a+3 < MEM_BYTES) begin
                        mem[a]   <= wd[7:0];
                        mem[a+1] <= wd[15:8];
                        mem[a+2] <= wd[23:16];
                        mem[a+3] <= wd[31:24];
                    end
                end
            endcase
        end
    end

    always @(*) begin
        rd = 32'h0;
        if (addr_ok) begin
            case (mode)
                3'b010: rd = {24'h0, mem[a]};
                3'b110: rd = {{24{mem[a][7]}}, mem[a]};
                3'b001: if (a+1 < MEM_BYTES) rd = {16'h0, mem[a+1], mem[a]};
                3'b101: if (a+1 < MEM_BYTES) rd = {{16{mem[a+1][7]}}, mem[a+1], mem[a]};
                default: if (a+3 < MEM_BYTES) rd = {mem[a+3], mem[a+2], mem[a+1], mem[a]};
            endcase
        end
    end
endmodule
