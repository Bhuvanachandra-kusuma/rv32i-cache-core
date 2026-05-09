// ============================================================
// Forwarding Unit
// Selects the correct data source for EX-stage ALU inputs.
//
// WHY THIS EXISTS:
//   After an R-type or I-type instruction writes a result, that
//   result sits in a pipeline register for 1–2 cycles before
//   reaching the register file writeback. If the next instruction
//   needs that result, we forward it directly from the pipeline
//   register instead of waiting for writeback.
//
// FORWARDING PATHS:
//   EX-EX forward:  result from EX/MEM register → current EX input
//                   (covers the 1-cycle gap: instr N+1 after instr N)
//   MEM-EX forward: result from MEM/WB register → current EX input
//                   (covers the 2-cycle gap: instr N+2 after instr N)
//
// PRIORITY: EX-EX takes priority over MEM-EX.
//   If both conditions match (back-to-back identical destinations,
//   rare but possible), the most recent result (EX/MEM) is correct.
//
// OUTPUT ENCODING (forward_a, forward_b):
//   2'b00 = use register file output (no hazard)
//   2'b10 = forward from EX/MEM stage (EX-EX path)
//   2'b01 = forward from MEM/WB stage (MEM-EX path)
// ============================================================

module forwarding_unit (
    // Current EX stage sources
    input  wire [4:0]  ex_rs1,
    input  wire [4:0]  ex_rs2,

    // EX/MEM register (1 cycle ahead)
    input  wire        mem_reg_write,
    input  wire [4:0]  mem_rd,

    // MEM/WB register (2 cycles ahead)
    input  wire        wb_reg_write,
    input  wire [4:0]  wb_rd,

    // Forwarding select signals for ALU inputs A and B
    output reg  [1:0]  forward_a,
    output reg  [1:0]  forward_b
);

    always @(*) begin
        // --- Forward A (rs1) ---
        if (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs1))
            forward_a = 2'b10;  // EX-EX forward
        else if (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs1))
            forward_a = 2'b01;  // MEM-EX forward
        else
            forward_a = 2'b00;  // no forward, use register file

        // --- Forward B (rs2) ---
        if (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs2))
            forward_b = 2'b10;  // EX-EX forward
        else if (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs2))
            forward_b = 2'b01;  // MEM-EX forward
        else
            forward_b = 2'b00;
    end

endmodule
