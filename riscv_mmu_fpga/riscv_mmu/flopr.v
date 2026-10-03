module flopr(d, q, clk, reset);

parameter WIDTH = 32;
parameter INIT = 0;

input wire reset;
input wire clk;
input wire [WIDTH-1:0] d;
output reg [WIDTH-1:0] q;

always @(posedge clk or posedge reset) begin
if (reset)
q <= {WIDTH{1'b0}};
else
q <= d;
end

endmodule

