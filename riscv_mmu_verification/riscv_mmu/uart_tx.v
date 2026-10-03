// Minimal 8-N-1 UART transmitter.
module uart_tx #(parameter CLK_FREQ_HZ=50_000_000, parameter BAUD=115200)(
    input wire clk, reset,
    input wire start,
    input wire [7:0] data,
    output reg tx,
    output reg busy
);
    localparam integer DIV = (CLK_FREQ_HZ/BAUD);
    reg [31:0] count;
    reg [3:0] bit_index;
    reg [9:0] shift;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx <= 1'b1;
            busy <= 1'b0;
            count <= 0;
            bit_index <= 0;
            shift <= 10'h3FF;
        end else if (!busy) begin
            tx <= 1'b1;
            count <= 0;
            if (start) begin
                shift <= {1'b1, data, 1'b0};
                bit_index <= 0;
                busy <= 1'b1;
                tx <= 1'b0;
            end
        end else if (count == DIV-1) begin
            count <= 0;
            if (bit_index == 4'd9) begin
                busy <= 1'b0;
                tx <= 1'b1;
            end else begin
                bit_index <= bit_index + 1'b1;
                shift <= {1'b1, shift[9:1]};
                tx <= shift[1];
            end
        end else begin
            count <= count + 1'b1;
        end
    end
endmodule
