// RV32I single-cycle control. Preserves the original project's control encoding.
module control_logic(inst, jump, ALUControl, dmemMode,
                     immSEL, regSEL, pcSEL, dmemWE,
                     regWE, rs1SEL, rs2SEL, clk, reset);
    input wire [31:0] inst;
    input wire jump, clk, reset;
    output reg [3:0] ALUControl;
    output reg [2:0] dmemMode, immSEL;
    output reg [1:0] regSEL, pcSEL;
    output reg dmemWE, regWE, rs1SEL, rs2SEL;

    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];

    always @(*) begin
        dmemMode   = 3'b000;
        dmemWE     = 1'b0;
        regWE      = 1'b0;
        rs1SEL     = 1'b0;
        rs2SEL     = 1'b0;
        regSEL     = 2'b00;
        pcSEL      = 2'b00;
        immSEL     = 3'b000;
        ALUControl = 4'b0000;

        case (opcode)
            7'b0110111: begin // LUI
                regWE = 1'b1; regSEL = 2'b10;
            end
            7'b0010111: begin // AUIPC
                regWE = 1'b1; rs1SEL = 1'b1; rs2SEL = 1'b1; regSEL = 2'b01;
            end
            7'b1101111: begin // JAL
                regWE = 1'b1; regSEL = 2'b11; pcSEL = 2'b10; immSEL = 3'b100;
            end
            7'b1100111: begin // JALR
                regWE = 1'b1; rs2SEL = 1'b1; regSEL = 2'b11; pcSEL = 2'b01;
                immSEL = 3'b011; ALUControl = 4'b1101;
            end
            7'b1100011: begin // Branches
                immSEL = 3'b010;
                case (funct3)
                    3'b000: begin ALUControl = 4'b1000; pcSEL = jump ? 2'b10 : 2'b00; end // BEQ
                    3'b001: begin ALUControl = 4'b1000; pcSEL = jump ? 2'b00 : 2'b10; end // BNE
                    3'b100: begin ALUControl = 4'b1010; pcSEL = jump ? 2'b10 : 2'b00; end // BLT
                    3'b101: begin ALUControl = 4'b1100; pcSEL = jump ? 2'b10 : 2'b00; end // BGE
                    3'b110: begin ALUControl = 4'b1001; pcSEL = jump ? 2'b10 : 2'b00; end // BLTU
                    3'b111: begin ALUControl = 4'b1011; pcSEL = jump ? 2'b10 : 2'b00; end // BGEU
                    default: begin ALUControl = 4'b1000; pcSEL = 2'b00; end
                endcase
            end
            7'b0000011: begin // Loads
                regWE = 1'b1; rs2SEL = 1'b1; immSEL = 3'b011; ALUControl = 4'b0000;
                case (funct3)
                    3'b000: dmemMode = 3'b110; // LB
                    3'b001: dmemMode = 3'b101; // LH
                    3'b010: dmemMode = 3'b000; // LW
                    3'b100: dmemMode = 3'b010; // LBU
                    3'b101: dmemMode = 3'b001; // LHU
                    default: begin regWE = 1'b0; dmemMode = 3'b000; end
                endcase
            end
            7'b0100011: begin // Stores
                dmemWE = 1'b1; rs2SEL = 1'b1; immSEL = 3'b001; ALUControl = 4'b0000;
                case (funct3)
                    3'b000: dmemMode = 3'b010; // SB
                    3'b001: dmemMode = 3'b001; // SH
                    3'b010: dmemMode = 3'b000; // SW
                    default: begin dmemWE = 1'b0; dmemMode = 3'b000; end
                endcase
            end
            7'b0010011: begin // Immediate ALU
                regWE = 1'b1; rs2SEL = 1'b1; regSEL = 2'b01; immSEL = 3'b011;
                case (funct3)
                    3'b000: ALUControl = 4'b0000; // ADDI
                    3'b010: ALUControl = 4'b1010; // SLTI
                    3'b011: ALUControl = 4'b1001; // SLTIU
                    3'b100: ALUControl = 4'b0100; // XORI
                    3'b110: ALUControl = 4'b0011; // ORI
                    3'b111: ALUControl = 4'b0010; // ANDI
                    3'b001: if (funct7 == 7'b0000000) ALUControl = 4'b0101; // SLLI
                    3'b101: if (funct7 == 7'b0000000) ALUControl = 4'b0110;
                              else if (funct7 == 7'b0100000) ALUControl = 4'b0111;
                    default: begin regWE = 1'b0; end
                endcase
            end
            7'b0110011: begin // Register ALU
                regWE = 1'b1; regSEL = 2'b01;
                case (funct7)
                    7'b0000000: begin
                        case (funct3)
                            3'b000: ALUControl = 4'b0000; // ADD
                            3'b001: ALUControl = 4'b0101; // SLL
                            3'b010: ALUControl = 4'b1010; // SLT
                            3'b011: ALUControl = 4'b1001; // SLTU
                            3'b100: ALUControl = 4'b0100; // XOR
                            3'b101: ALUControl = 4'b0110; // SRL
                            3'b110: ALUControl = 4'b0011; // OR
                            3'b111: ALUControl = 4'b0010; // AND
                            default: regWE = 1'b0;
                        endcase
                    end
                    7'b0100000: begin
                        case (funct3)
                            3'b000: ALUControl = 4'b0001; // SUB
                            3'b101: ALUControl = 4'b0111; // SRA
                            default: regWE = 1'b0;
                        endcase
                    end
                    default: regWE = 1'b0;
                endcase
            end
            default: ; // NOP / unsupported instruction
        endcase
    end
endmodule
