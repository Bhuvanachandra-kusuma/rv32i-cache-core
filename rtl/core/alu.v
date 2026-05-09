// ============================================================
// alu.v — RV32I Arithmetic Logic Unit
//
// Supports all operations needed by RV32I:
//   ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
//
// alu_op encoding (matches control decoder output):
//   4'b0000 = ADD
//   4'b0001 = SUB
//   4'b0010 = AND
//   4'b0011 = OR
//   4'b0100 = XOR
//   4'b0101 = SLL  (shift left logical)
//   4'b0110 = SRL  (shift right logical)
//   4'b0111 = SRA  (shift right arithmetic)
//   4'b1000 = SLT  (set less than, signed)
//   4'b1001 = SLTU (set less than, unsigned)
//   4'b1010 = LUI passthrough (result = b, used for LUI/AUIPC)
// ============================================================

module alu (
    input  wire [3:0]  alu_op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] result,
    output wire        zero        // used by branch comparator
);

    wire signed [31:0] a_s = a;
    wire signed [31:0] b_s = b;

    always @(*) begin
        case (alu_op)
            4'b0000: result = a + b;                          // ADD
            4'b0001: result = a - b;                          // SUB
            4'b0010: result = a & b;                          // AND
            4'b0011: result = a | b;                          // OR
            4'b0100: result = a ^ b;                          // XOR
            4'b0101: result = a << b[4:0];                    // SLL
            4'b0110: result = a >> b[4:0];                    // SRL
            4'b0111: result = a_s >>> b[4:0];                 // SRA
            4'b1000: result = (a_s < b_s) ? 32'd1 : 32'd0;   // SLT
            4'b1001: result = (a < b)     ? 32'd1 : 32'd0;   // SLTU
            4'b1010: result = b;                              // LUI passthrough
            default: result = 32'b0;
        endcase
    end

    assign zero = (result == 32'b0);

endmodule
