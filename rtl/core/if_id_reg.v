// ============================================================
// IF/ID Pipeline Register
// Latches PC and raw instruction between Fetch and Decode.
//
// Flush: driven by branch taken — clears the instruction to NOP
//        so the wrongly-fetched instruction does nothing.
// Stall: driven by hazard unit — freezes both this register
//        and the PC, effectively re-fetching the same instruction.
// ============================================================

module if_id_reg (
    input  wire        clk,
    input  wire        rst_n,      // active-low synchronous reset

    // Control from hazard unit
    input  wire        stall,      // 1 = hold current values (do not advance)
    input  wire        flush,      // 1 = insert NOP (branch taken)

    // Inputs from IF stage
    input  wire [31:0] if_pc,
    input  wire [31:0] if_instr,

    // Outputs to ID stage
    output reg  [31:0] id_pc,
    output reg  [31:0] id_instr
);

    // NOP = ADDI x0, x0, 0  (32'h00000013)
    localparam NOP = 32'h0000_0013;

    always @(posedge clk) begin
        if (!rst_n || flush) begin
            id_pc    <= 32'b0;
            id_instr <= NOP;
        end else if (!stall) begin
            id_pc    <= if_pc;
            id_instr <= if_instr;
        end
        // stall=1, flush=0: retain current values (do nothing)
    end

endmodule
