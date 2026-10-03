// RV32I immediate generator. Instr is instruction[31:7].
module extend(input wire [24:0] Instr, input wire [2:0] ImmSrc,
              output reg [31:0] ExtImm);
    always @(*) begin
        case (ImmSrc)
            3'b000: ExtImm = {Instr[24:5], 12'b0}; // U
            3'b001: ExtImm = {{21{Instr[24]}}, Instr[24:18], Instr[4:0]}; // S
            3'b010: ExtImm = {{20{Instr[24]}}, Instr[0], Instr[23:18], Instr[4:1], 1'b0}; // B
            3'b011: ExtImm = {{20{Instr[24]}}, Instr[24:13]}; // I
            3'b100: ExtImm = {{12{Instr[24]}}, Instr[12:5], Instr[13], Instr[23:14], 1'b0}; // J
            default: ExtImm = 32'b0;
        endcase
    end
endmodule
