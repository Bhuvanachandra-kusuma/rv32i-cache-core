// id_ex_reg.v — ID/EX Pipeline Register with stall support
module id_ex_reg (
    input  wire        clk, rst_n, flush,
    input  wire        stall,  // 1 = hold current values
    input  wire [31:0] id_pc, id_rs1_data, id_rs2_data, id_imm,
    input  wire [4:0]  id_rs1, id_rs2, id_rd,
    input  wire [3:0]  id_alu_op,
    input  wire        id_alu_src, id_branch, id_jump,
    input  wire        id_mem_read, id_mem_write,
    input  wire [2:0]  id_mem_funct3,
    input  wire        id_reg_write,
    input  wire [1:0]  id_wb_sel,
    output reg  [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm,
    output reg  [4:0]  ex_rs1, ex_rs2, ex_rd,
    output reg  [3:0]  ex_alu_op,
    output reg         ex_alu_src, ex_branch, ex_jump,
    output reg         ex_mem_read, ex_mem_write,
    output reg  [2:0]  ex_mem_funct3,
    output reg         ex_reg_write,
    output reg  [1:0]  ex_wb_sel
);
    always @(posedge clk) begin
        if (!rst_n || flush) begin
            ex_pc<=0; ex_rs1_data<=0; ex_rs2_data<=0; ex_imm<=0;
            ex_rs1<=0; ex_rs2<=0; ex_rd<=0; ex_alu_op<=0;
            ex_alu_src<=0; ex_branch<=0; ex_jump<=0;
            ex_mem_read<=0; ex_mem_write<=0; ex_mem_funct3<=0;
            ex_reg_write<=0; ex_wb_sel<=0;
        end else if (!stall) begin
            ex_pc<=id_pc; ex_rs1_data<=id_rs1_data; ex_rs2_data<=id_rs2_data; ex_imm<=id_imm;
            ex_rs1<=id_rs1; ex_rs2<=id_rs2; ex_rd<=id_rd; ex_alu_op<=id_alu_op;
            ex_alu_src<=id_alu_src; ex_branch<=id_branch; ex_jump<=id_jump;
            ex_mem_read<=id_mem_read; ex_mem_write<=id_mem_write; ex_mem_funct3<=id_mem_funct3;
            ex_reg_write<=id_reg_write; ex_wb_sel<=id_wb_sel;
        end
    end
endmodule
