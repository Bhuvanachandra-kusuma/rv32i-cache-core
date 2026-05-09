// ============================================================
// Hazard Detection Unit
// Detects load-use data hazards and generates stall/flush signals.
//
// WHY THIS EXISTS:
//   A load (LW/LH/LB) reads memory in the MEM stage. Its result
//   is not available until the end of MEM — one cycle too late
//   for the immediately following instruction's EX stage.
//   Forwarding cannot solve this because the data doesn't exist yet.
//   The only fix is a one-cycle stall ("bubble insertion").
//
// LOAD-USE HAZARD detection:
//   If the EX-stage instruction is a load (ex_mem_read=1)
//   AND its destination matches either source of the ID-stage instruction,
//   stall for one cycle.
//
// BRANCH FLUSH:
//   When a branch is taken (resolved in EX), flush IF/ID and ID/EX
//   to discard the two wrongly-fetched instructions.
//   This implements a "flush on branch" strategy (assumes not-taken).
// ============================================================

module hazard_unit (
    // Load-use hazard detection
    input  wire        ex_mem_read,    // 1 if EX instruction is a load
    input  wire [4:0]  ex_rd,          // destination of EX instruction
    input  wire [4:0]  id_rs1,         // source 1 of ID instruction
    input  wire [4:0]  id_rs2,         // source 2 of ID instruction

    // Branch/jump control
    input  wire        ex_branch_taken, // branch resolved as taken in EX
    input  wire        ex_jump,         // JAL/JALR in EX (always flushes)

    // --- Outputs ---
    output reg         stall_if,        // freeze PC and IF/ID register
    output reg         stall_id,        // freeze IF/ID register (same as stall_if here)
    output reg         flush_id_ex,     // flush ID/EX (insert bubble into EX)
    output reg         flush_if_id      // flush IF/ID (branch taken)
);

    wire load_use_hazard;
    wire branch_flush;

    // Load-use: EX instruction is a load and destination matches ID sources
    // Guard against x0 (writes to x0 are discarded, never cause hazards)
    assign load_use_hazard = ex_mem_read &&
                             (ex_rd != 5'b0) &&
                             ((ex_rd == id_rs1) || (ex_rd == id_rs2));

    // Branch taken or unconditional jump → flush two stages
    assign branch_flush = ex_branch_taken || ex_jump;

    always @(*) begin
        // Defaults
        stall_if    = 1'b0;
        stall_id    = 1'b0;
        flush_id_ex = 1'b0;
        flush_if_id = 1'b0;

        if (load_use_hazard) begin
            // Stall PC and IF/ID, insert bubble into ID/EX
            stall_if    = 1'b1;
            stall_id    = 1'b1;
            flush_id_ex = 1'b1;
        end

        if (branch_flush) begin
            // Discard IF and ID stage instructions (they are wrong-path)
            flush_if_id = 1'b1;
            flush_id_ex = 1'b1;
        end
    end

endmodule
