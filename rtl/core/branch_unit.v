// ============================================================
// branch_unit.v — RV32I Branch Condition Evaluator
//
// Evaluates the branch taken/not-taken decision in EX stage.
// Uses the forwarded rs1/rs2 values directly (not ALU result)
// so we can handle all branch types cleanly.
//
// funct3 encoding:
//   3'b000 = BEQ   (branch if equal)
//   3'b001 = BNE   (branch if not equal)
//   3'b100 = BLT   (branch if less than, signed)
//   3'b101 = BGE   (branch if greater or equal, signed)
//   3'b110 = BLTU  (branch if less than, unsigned)
//   3'b111 = BGEU  (branch if greater or equal, unsigned)
// ============================================================

module branch_unit (
    input  wire [31:0] rs1_data,    // forwarded operand A
    input  wire [31:0] rs2_data,    // forwarded operand B
    input  wire [2:0]  funct3,
    input  wire        branch,      // is this a branch instruction?
    input  wire        jump,        // is this JAL/JALR?
    output reg         taken        // 1 = branch/jump taken
);

    wire signed [31:0] rs1_s = rs1_data;
    wire signed [31:0] rs2_s = rs2_data;

    reg branch_cond;

    always @(*) begin
        case (funct3)
            3'b000: branch_cond = (rs1_data == rs2_data);          // BEQ
            3'b001: branch_cond = (rs1_data != rs2_data);          // BNE
            3'b100: branch_cond = (rs1_s < rs2_s);                 // BLT
            3'b101: branch_cond = (rs1_s >= rs2_s);                // BGE
            3'b110: branch_cond = (rs1_data < rs2_data);           // BLTU
            3'b111: branch_cond = (rs1_data >= rs2_data);          // BGEU
            default: branch_cond = 1'b0;
        endcase

        taken = (branch && branch_cond) || jump;
    end

endmodule
