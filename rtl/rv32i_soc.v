// ============================================================
// rv32i_soc.v — Top-Level SoC
//
// Connects: rv32i_pipeline_core + icache + dcache + sram_model
// This is the simulation top. For FPGA, swap sram_model for
// a Xilinx BRAM primitive.
// ============================================================

module rv32i_soc #(
    parameter MEM_INIT_FILE = "program.hex"
) (
    input  wire clk,
    input  wire rst_n
);

    // ---- CPU <-> I-cache wires ----
    wire [31:0] cpu_imem_addr, cpu_imem_data;
    wire        cpu_imem_req,  cpu_imem_valid, icache_stall;

    // ---- CPU <-> D-cache wires ----
    wire [31:0] cpu_dmem_addr, cpu_dmem_wdata, cpu_dmem_rdata;
    wire        cpu_dmem_we,   cpu_dmem_req,   dcache_stall;
    wire [2:0]  cpu_dmem_funct3;

    // ---- I-cache <-> SRAM port A ----
    wire [31:0] ic_mem_addr, ic_mem_rdata;
    wire        ic_mem_req, ic_mem_valid;

    // ---- D-cache <-> SRAM port B ----
    wire [31:0] dc_mem_addr, dc_mem_wdata, dc_mem_rdata;
    wire        dc_mem_we, dc_mem_req, dc_mem_valid;

    // ---- Pipeline core ----
    rv32i_pipeline_core u_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (cpu_imem_addr),
        .imem_data  (cpu_imem_data),
        .imem_valid (cpu_imem_valid),
        .imem_req   (cpu_imem_req),
        .dmem_addr  (cpu_dmem_addr),
        .dmem_wdata (cpu_dmem_wdata),
        .dmem_we    (cpu_dmem_we),
        .dmem_funct3(cpu_dmem_funct3),
        .dmem_req   (cpu_dmem_req),
        .dmem_rdata (cpu_dmem_rdata),
        .dmem_stall (dcache_stall)
    );

    // ---- Instruction cache ----
    icache u_icache (
        .clk       (clk),
        .rst_n     (rst_n),
        .cpu_addr  (cpu_imem_addr),
        .cpu_req   (cpu_imem_req),
        .cpu_rdata (cpu_imem_data),
        .cpu_hit   (cpu_imem_valid),
        .cpu_stall (icache_stall),
        .mem_addr  (ic_mem_addr),
        .mem_req   (ic_mem_req),
        .mem_rdata (ic_mem_rdata),
        .mem_valid (ic_mem_valid)
    );

    // ---- Data cache ----
    dcache u_dcache (
        .clk       (clk),
        .rst_n     (rst_n),
        .cpu_addr  (cpu_dmem_addr),
        .cpu_wdata (cpu_dmem_wdata),
        .cpu_we    (cpu_dmem_we),
        .cpu_req   (cpu_dmem_req),
        .cpu_funct3(cpu_dmem_funct3),
        .cpu_rdata (cpu_dmem_rdata),
        .cpu_stall (dcache_stall),
        .mem_addr  (dc_mem_addr),
        .mem_wdata (dc_mem_wdata),
        .mem_we    (dc_mem_we),
        .mem_req   (dc_mem_req),
        .mem_rdata (dc_mem_rdata),
        .mem_valid (dc_mem_valid)
    );

    // ---- Shared SRAM (dual-port: A=instr, B=data) ----
    sram_model #(
        .MEM_INIT_FILE(MEM_INIT_FILE),
        .LATENCY(2)
    ) u_sram (
        .clk    (clk),
        .rst_n  (rst_n),
        .a_addr (ic_mem_addr),
        .a_req  (ic_mem_req),
        .a_rdata(ic_mem_rdata),
        .a_valid(ic_mem_valid),
        .b_addr (dc_mem_addr),
        .b_wdata(dc_mem_wdata),
        .b_we   (dc_mem_we),
        .b_req  (dc_mem_req),
        .b_rdata(dc_mem_rdata),
        .b_valid(dc_mem_valid)
    );

endmodule
