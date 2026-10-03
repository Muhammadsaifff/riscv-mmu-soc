module alu32(a, b, ALUControl, result);
    input wire [31:0] a, b;
    input wire [3:0] ALUControl;
    output reg [31:0] result;
    wire signed [31:0] a_signed = a;
    wire signed [31:0] b_signed = b;
    always @(*) begin
        case (ALUControl)
            4'b0000: result = a + b;
            4'b0001: result = a - b;
            4'b0010: result = a & b;
            4'b0011: result = a | b;
            4'b0100: result = a ^ b;
            4'b0101: result = a << b[4:0];
            4'b0110: result = a >> b[4:0];
            4'b0111: result = a_signed >>> b[4:0];
            4'b1000: result = (a == b) ? 32'd1 : 32'd0;
            4'b1001: result = (a < b) ? 32'd1 : 32'd0;
            4'b1010: result = (a_signed < b_signed) ? 32'd1 : 32'd0;
            4'b1011: result = (a >= b) ? 32'd1 : 32'd0;
            4'b1100: result = (a_signed >= b_signed) ? 32'd1 : 32'd0;
            4'b1101: result = (a + b) & 32'hFFFFFFFE;
            default: result = 32'b0;
        endcase
    end
endmodule
