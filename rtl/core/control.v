// ============================================================
// control.v — RV32I Control Decoder
//
// Combinational decode of opcode + funct3 + funct7[5] into
// all pipeline control signals.
//
// alu_op encoding:
//   ADD=0000, SUB=0001, AND=0010, OR=0011, XOR=0100,
//   SLL=0101, SRL=0110, SRA=0111, SLT=1000, SLTU=1001, LUI=1010
//
// wb_sel encoding:
//   2'b00 = ALU result
//   2'b01 = Memory load data
//   2'b10 = PC+4 (JAL/JALR link)
// ============================================================

module control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       funct7_5,    // instr[30]

    output reg  [3:0] alu_op,
    output reg        alu_src,     // 0=rs2, 1=imm
    output reg        branch,
    output reg        jump,
    output reg        mem_read,
    output reg        mem_write,
    output reg        reg_write,
    output reg  [1:0] wb_sel
);

    always @(*) begin
        // Defaults
        alu_op    = 4'b0000;  // ADD
        alu_src   = 1'b0;
        branch    = 1'b0;
        jump      = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        reg_write = 1'b0;
        wb_sel    = 2'b00;

        case (opcode)
            // R-type
            7'b0110011: begin
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_op = funct7_5 ? 4'b0001 : 4'b0000; // SUB:ADD
                    3'b001: alu_op = 4'b0101; // SLL
                    3'b010: alu_op = 4'b1000; // SLT
                    3'b011: alu_op = 4'b1001; // SLTU
                    3'b100: alu_op = 4'b0100; // XOR
                    3'b101: alu_op = funct7_5 ? 4'b0111 : 4'b0110; // SRA:SRL
                    3'b110: alu_op = 4'b0011; // OR
                    3'b111: alu_op = 4'b0010; // AND
                    default: alu_op = 4'b0000;
                endcase
            end

            // I-type ALU
            7'b0010011: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_op = 4'b0000; // ADDI
                    3'b001: alu_op = 4'b0101; // SLLI
                    3'b010: alu_op = 4'b1000; // SLTI
                    3'b011: alu_op = 4'b1001; // SLTIU
                    3'b100: alu_op = 4'b0100; // XORI
                    3'b101: alu_op = funct7_5 ? 4'b0111 : 4'b0110; // SRAI:SRLI
                    3'b110: alu_op = 4'b0011; // ORI
                    3'b111: alu_op = 4'b0010; // ANDI
                    default: alu_op = 4'b0000;
                endcase
            end

            // LOAD
            7'b0000011: begin
                alu_src   = 1'b1;
                mem_read  = 1'b1;
                reg_write = 1'b1;
                wb_sel    = 2'b01;
                alu_op    = 4'b0000; // ADD (base + offset)
            end

            // STORE
            7'b0100011: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_op    = 4'b0000; // ADD (base + offset)
            end

            // BRANCH
            7'b1100011: begin
                branch = 1'b1;
                // ALU computes comparison; branch condition checked separately
                case (funct3)
                    3'b000: alu_op = 4'b0001; // BEQ  → SUB, check zero
                    3'b001: alu_op = 4'b0001; // BNE  → SUB, check ~zero
                    3'b100: alu_op = 4'b1000; // BLT  → SLT
                    3'b101: alu_op = 4'b1000; // BGE  → SLT, invert
                    3'b110: alu_op = 4'b1001; // BLTU → SLTU
                    3'b111: alu_op = 4'b1001; // BGEU → SLTU, invert
                    default: alu_op = 4'b0001;
                endcase
            end

            // JAL
            7'b1101111: begin
                jump      = 1'b1;
                reg_write = 1'b1;
                wb_sel    = 2'b10; // PC+4
            end

            // JALR
            7'b1100111: begin
                jump      = 1'b1;
                alu_src   = 1'b1;
                reg_write = 1'b1;
                wb_sel    = 2'b10; // PC+4
                alu_op    = 4'b0000; // ADD (rs1 + imm)
            end

            // LUI
            7'b0110111: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                alu_op    = 4'b1010; // LUI passthrough
            end

            // AUIPC
            7'b0010111: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                alu_op    = 4'b0000; // ADD (PC + imm)
            end

            default: begin
                // NOP / unrecognised — all signals stay at default (no-op)
            end
        endcase
    end

endmodule
