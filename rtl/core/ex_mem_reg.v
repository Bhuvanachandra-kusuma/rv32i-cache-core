// ex_mem_reg.v — EX/MEM Pipeline Register with stall support
module ex_mem_reg (
    input  wire        clk, rst_n,
    input  wire        stall,
    input  wire [31:0] ex_alu_result, ex_rs2_data, ex_branch_target, ex_pc_plus4,
    input  wire [4:0]  ex_rd,
    input  wire        ex_branch_taken,
    input  wire        ex_mem_read, ex_mem_write,
    input  wire [2:0]  ex_mem_funct3,
    input  wire        ex_reg_write,
    input  wire [1:0]  ex_wb_sel,
    output reg  [31:0] mem_alu_result, mem_rs2_data, mem_branch_target, mem_pc_plus4,
    output reg  [4:0]  mem_rd,
    output reg         mem_branch_taken,
    output reg         mem_mem_read, mem_mem_write,
    output reg  [2:0]  mem_mem_funct3,
    output reg         mem_reg_write,
    output reg  [1:0]  mem_wb_sel
);
    always @(posedge clk) begin
        if (!rst_n) begin
            mem_alu_result<=0; mem_rs2_data<=0; mem_branch_target<=0; mem_pc_plus4<=0;
            mem_rd<=0; mem_branch_taken<=0; mem_mem_read<=0; mem_mem_write<=0;
            mem_mem_funct3<=0; mem_reg_write<=0; mem_wb_sel<=0;
        end else if (!stall) begin
            mem_alu_result<=ex_alu_result; mem_rs2_data<=ex_rs2_data;
            mem_branch_target<=ex_branch_target; mem_pc_plus4<=ex_pc_plus4;
            mem_rd<=ex_rd; mem_branch_taken<=ex_branch_taken;
            mem_mem_read<=ex_mem_read; mem_mem_write<=ex_mem_write;
            mem_mem_funct3<=ex_mem_funct3; mem_reg_write<=ex_reg_write; mem_wb_sel<=ex_wb_sel;
        end
    end
endmodule
