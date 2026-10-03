module flopr(d, q, clk, reset);
	parameter WIDTH = 32;
	parameter INIT = 0;

	input wire				reset, clk;
	input wire [WIDTH - 1:0]	d;
	output reg [WIDTH - 1:0]	q;
	
	initial q = INIT;
	
	// Change to synchronous reset for Yosys compatibility
	always @(posedge clk) begin
		if (reset)
			q <= {WIDTH{1'b0}};
		else
			q <= d;
	end

endmodule
