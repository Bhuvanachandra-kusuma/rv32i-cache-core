// ============================================================
// tb_pipeline.v — Testbench for Phase 1 pipeline units
//
// Tests:
//   1. Normal flow    — instructions advance through all 4 registers
//   2. Flush (branch) — flush_if_id + flush_id_ex insert NOPs
//   3. Stall          — load-use hazard freezes IF/ID + IF for 1 cycle
//   4. Forwarding     — EX-EX and MEM-EX paths select correct data
//
// Run with:
//   iverilog -o sim/tb_pipeline tb/tb_pipeline.v \
//     rtl/core/if_id_reg.v rtl/core/id_ex_reg.v \
//     rtl/core/ex_mem_reg.v rtl/core/mem_wb_reg.v \
//     rtl/core/hazard_unit.v rtl/core/forwarding_unit.v
//   vvp sim/tb_pipeline
//   gtkwave sim/tb_pipeline.vcd
// ============================================================

`timescale 1ns/1ps

module tb_pipeline;

    // ---- Clock & reset ----
    reg clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk; // 10 ns period = 100 MHz

    // ---- IF/ID signals ----
    reg         stall_if_id, flush_if_id;
    reg  [31:0] if_pc, if_instr;
    wire [31:0] id_pc, id_instr;

    if_id_reg u_if_id (
        .clk(clk), .rst_n(rst_n),
        .stall(stall_if_id), .flush(flush_if_id),
        .if_pc(if_pc), .if_instr(if_instr),
        .id_pc(id_pc), .id_instr(id_instr)
    );

    // ---- ID/EX signals ----
    reg         flush_id_ex;
    wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire [3:0]  ex_alu_op;
    wire        ex_alu_src, ex_branch, ex_jump;
    wire        ex_mem_read, ex_mem_write;
    wire [2:0]  ex_mem_funct3;
    wire        ex_reg_write;
    wire [1:0]  ex_wb_sel;

    // Drive ID/EX inputs directly from IF/ID outputs (simplified)
    id_ex_reg u_id_ex (
        .stall(1'b0),
        .clk(clk), .rst_n(rst_n), .flush(flush_id_ex),
        .id_pc(id_pc), .id_rs1_data(32'hAAAA_0001), .id_rs2_data(32'hBBBB_0002),
        .id_imm(32'h0000_0010), .id_rs1(5'd1), .id_rs2(5'd2), .id_rd(5'd3),
        .id_alu_op(4'b0010), .id_alu_src(1'b0), .id_branch(1'b0), .id_jump(1'b0),
        .id_mem_read(1'b0), .id_mem_write(1'b0), .id_mem_funct3(3'b010),
        .id_reg_write(1'b1), .id_wb_sel(2'b00),
        .ex_pc(ex_pc), .ex_rs1_data(ex_rs1_data), .ex_rs2_data(ex_rs2_data),
        .ex_imm(ex_imm), .ex_rs1(ex_rs1), .ex_rs2(ex_rs2), .ex_rd(ex_rd),
        .ex_alu_op(ex_alu_op), .ex_alu_src(ex_alu_src),
        .ex_branch(ex_branch), .ex_jump(ex_jump),
        .ex_mem_read(ex_mem_read), .ex_mem_write(ex_mem_write),
        .ex_mem_funct3(ex_mem_funct3),
        .ex_reg_write(ex_reg_write), .ex_wb_sel(ex_wb_sel)
    );

    // ---- Hazard unit ----
    reg  ex_mem_read_h; // separate input to hazard from ex_mem_read above
    reg  [4:0] ex_rd_h, id_rs1_h, id_rs2_h;
    reg  branch_taken_h, jump_h;
    wire stall_if_o, stall_id_o, flush_id_ex_o, flush_if_id_o;

    hazard_unit u_haz (
        .ex_mem_read(ex_mem_read_h), .ex_rd(ex_rd_h),
        .id_rs1(id_rs1_h), .id_rs2(id_rs2_h),
        .ex_branch_taken(branch_taken_h), .ex_jump(jump_h),
        .stall_if(stall_if_o), .stall_id(stall_id_o),
        .flush_id_ex(flush_id_ex_o), .flush_if_id(flush_if_id_o)
    );

    // ---- Forwarding unit ----
    reg  [4:0]  fwd_ex_rs1, fwd_ex_rs2, fwd_mem_rd, fwd_wb_rd;
    reg         fwd_mem_rw, fwd_wb_rw;
    wire [1:0]  fwd_a, fwd_b;

    forwarding_unit u_fwd (
        .ex_rs1(fwd_ex_rs1), .ex_rs2(fwd_ex_rs2),
        .mem_reg_write(fwd_mem_rw), .mem_rd(fwd_mem_rd),
        .wb_reg_write(fwd_wb_rw),  .wb_rd(fwd_wb_rd),
        .forward_a(fwd_a), .forward_b(fwd_b)
    );

    // ---- VCD dump ----
    initial begin
        $dumpfile("sim/tb_pipeline.vcd");
        $dumpvars(0, tb_pipeline);
    end

    // ---- Task: check ----
    task check;
        input [255:0] label;
        input         condition;
        begin
            if (condition)
                $display("  PASS  %s", label);
            else
                $display("  FAIL  %s", label);
        end
    endtask

    // ---- Test sequence ----
    initial begin
        $display("\n=== Phase 1 Pipeline Register Tests ===\n");

        // Reset
        rst_n = 0; stall_if_id = 0; flush_if_id = 0; flush_id_ex = 0;
        if_pc = 0; if_instr = 32'h0000_0013; // NOP
        ex_mem_read_h = 0; ex_rd_h = 0; id_rs1_h = 0; id_rs2_h = 0;
        branch_taken_h = 0; jump_h = 0;
        fwd_ex_rs1 = 0; fwd_ex_rs2 = 0;
        fwd_mem_rd = 0; fwd_mem_rw = 0;
        fwd_wb_rd  = 0; fwd_wb_rw  = 0;
        @(posedge clk); #1;
        rst_n = 1;

        // ---- TEST 1: Normal flow ----
        $display("--- Test 1: Normal flow ---");
        if_pc = 32'h0000_1000;
        if_instr = 32'hAABB_CCDD;
        @(posedge clk); #1;
        check("IF/ID latches PC",    id_pc    == 32'h0000_1000);
        check("IF/ID latches instr", id_instr == 32'hAABB_CCDD);
        @(posedge clk); #1;
        check("ID/EX advances PC",   ex_pc == 32'h0000_1000);
        check("ID/EX reg_write=1",   ex_reg_write == 1'b1);

        // ---- TEST 2: Flush (branch taken) ----
        $display("--- Test 2: Branch flush ---");
        flush_if_id = 1; flush_id_ex = 1;
        if_pc = 32'h0000_2000; if_instr = 32'hDEAD_BEEF;
        @(posedge clk); #1;
        flush_if_id = 0; flush_id_ex = 0;
        check("IF/ID flushed to NOP",    id_instr == 32'h0000_0013);
        check("ID/EX flushed, no write", ex_reg_write == 1'b0);

        // ---- TEST 3: Stall (load-use hazard) ----
        $display("--- Test 3: Load-use stall ---");
        // Simulate: LW x3, 0(x1) in EX, next instr uses x3
        ex_mem_read_h = 1; ex_rd_h = 5'd3;
        id_rs1_h = 5'd3; id_rs2_h = 5'd0;
        #1;
        check("Load-use: stall_if asserted",  stall_if_o  == 1'b1);
        check("Load-use: stall_id asserted",  stall_id_o  == 1'b1);
        check("Load-use: flush_id_ex",        flush_id_ex_o == 1'b1);
        ex_mem_read_h = 0; // clear hazard

        // ---- TEST 4: Forwarding unit ----
        $display("--- Test 4: Forwarding paths ---");

        // EX-EX: mem_rd == ex_rs1
        fwd_ex_rs1 = 5'd5; fwd_ex_rs2 = 5'd7;
        fwd_mem_rd = 5'd5; fwd_mem_rw = 1;
        fwd_wb_rd  = 5'd0; fwd_wb_rw  = 0;
        #1;
        check("EX-EX forward A (2'b10)", fwd_a == 2'b10);
        check("No forward B",            fwd_b == 2'b00);

        // MEM-EX: wb_rd == ex_rs2 (no mem conflict)
        fwd_mem_rd = 5'd9; fwd_mem_rw = 1; // different rd
        fwd_wb_rd  = 5'd7; fwd_wb_rw  = 1;
        #1;
        check("MEM-EX forward B (2'b01)", fwd_b == 2'b01);

        // EX-EX takes priority over MEM-EX on same register
        fwd_mem_rd = 5'd5; fwd_wb_rd = 5'd5;
        fwd_mem_rw = 1;    fwd_wb_rw = 1;
        #1;
        check("EX-EX priority over MEM-EX for A", fwd_a == 2'b10);

        // x0 never forwarded
        fwd_ex_rs1 = 5'd0; fwd_mem_rd = 5'd0; fwd_mem_rw = 1;
        #1;
        check("x0 not forwarded",  fwd_a == 2'b00);

        // ---- TEST 5: Branch flush from hazard unit ----
        $display("--- Test 5: Branch flush from hazard ---");
        ex_mem_read_h = 0; ex_rd_h = 5'd0;
        branch_taken_h = 1;
        #1;
        check("Branch: flush_if_id", flush_if_id_o == 1'b1);
        check("Branch: flush_id_ex", flush_id_ex_o == 1'b1);
        check("Branch: no stall",    stall_if_o    == 1'b0);
        branch_taken_h = 0;

        $display("\n=== All tests complete ===\n");
        $finish;
    end

endmodule
