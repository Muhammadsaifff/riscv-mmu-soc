module dmem #(parameter MEM_BYTES=8192)(
    input wire [31:0] a,
    output reg [31:0] rd,
    input wire [31:0] wd,
    input wire clk,
    input wire we,
    input wire [2:0] mode,
    input wire reset
);

    localparam WORDS = MEM_BYTES / 4;
    localparam ADDR_WIDTH = $clog2(WORDS);

    reg [31:0] mem [0:WORDS-1];

    wire [ADDR_WIDTH-1:0] word_addr;
    assign word_addr = a[ADDR_WIDTH+1:2];

    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            mem[i] = 32'h00000000;
    end

    always @(posedge clk) begin
        if (!reset) begin

            if (we && (a[31:ADDR_WIDTH+2] == 0)) begin
                case (mode)

                    3'b010,
                    3'b110: begin
                        case (a[1:0])
                            2'b00: mem[word_addr][7:0]   <= wd[7:0];
                            2'b01: mem[word_addr][15:8]  <= wd[7:0];
                            2'b10: mem[word_addr][23:16] <= wd[7:0];
                            2'b11: mem[word_addr][31:24] <= wd[7:0];
                        endcase
                    end

                    3'b001,
                    3'b101: begin
                        if (a[1:0] == 2'b00)
                            mem[word_addr][15:0] <= wd[15:0];
                        else if (a[1:0] == 2'b10)
                            mem[word_addr][31:16] <= wd[15:0];
                    end

                    default: begin
                        if (a[1:0] == 2'b00)
                            mem[word_addr] <= wd;
                    end

                endcase
            end

            if (a[31:ADDR_WIDTH+2] == 0) begin

                case (mode)

                    3'b010: begin
                        case (a[1:0])
                            2'b00: rd <= {24'h0, mem[word_addr][7:0]};
                            2'b01: rd <= {24'h0, mem[word_addr][15:8]};
                            2'b10: rd <= {24'h0, mem[word_addr][23:16]};
                            2'b11: rd <= {24'h0, mem[word_addr][31:24]};
                        endcase
                    end

                    3'b110: begin
                        case (a[1:0])
                            2'b00: rd <= {{24{mem[word_addr][7]}}, mem[word_addr][7:0]};
                            2'b01: rd <= {{24{mem[word_addr][15]}}, mem[word_addr][15:8]};
                            2'b10: rd <= {{24{mem[word_addr][23]}}, mem[word_addr][23:16]};
                            2'b11: rd <= {{24{mem[word_addr][31]}}, mem[word_addr][31:24]};
                        endcase
                    end

                    3'b001: begin
                        if (a[1:0] == 2'b00)
                            rd <= {16'h0000, mem[word_addr][15:0]};
                        else if (a[1:0] == 2'b10)
                            rd <= {16'h0000, mem[word_addr][31:16]};
                        else
                            rd <= 32'h00000000;
                    end

                    3'b101: begin
                        if (a[1:0] == 2'b00)
                            rd <= {{16{mem[word_addr][15]}}, mem[word_addr][15:0]};
                        else if (a[1:0] == 2'b10)
                            rd <= {{16{mem[word_addr][31]}}, mem[word_addr][31:16]};
                        else
                            rd <= 32'h00000000;
                    end

                    default: begin
                        rd <= mem[word_addr];
                    end

                endcase

            end
            else begin
                rd <= 32'h00000000;
            end
        end
    end

endmodule
