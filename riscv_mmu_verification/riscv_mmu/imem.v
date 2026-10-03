// 4-KiB instruction memory. Address is byte based and instruction aligned.
module imem #(parameter MEM_BYTES=4096, parameter INITIAL_DATA_PATH="imem.dat")(
    input wire [31:0] a,
    output wire [31:0] rd
);
    localparam WORDS = MEM_BYTES/4;
    reg [31:0] mem [0:WORDS-1];
    integer i;
    initial begin
        for (i=0; i<WORDS; i=i+1) mem[i] = 32'h00000013; // ADDI x0,x0,0
        $readmemh(INITIAL_DATA_PATH, mem);
    end
    assign rd = (a[31:12] == 20'h0 && a[1:0] == 2'b00) ? mem[a[11:2]] : 32'h00000013;
endmodule
