// mem_wb_reg.v — MEM/WB Pipeline Register with stall support
module mem_wb_reg (
    input  wire        clk, rst_n,
    input  wire        stall,
    input  wire [31:0] mem_alu_result, mem_read_data, mem_pc_plus4,
    input  wire [4:0]  mem_rd,
    input  wire        mem_reg_write,
    input  wire [1:0]  mem_wb_sel,
    output reg  [31:0] wb_alu_result, wb_read_data, wb_pc_plus4,
    output reg  [4:0]  wb_rd,
    output reg         wb_reg_write,
    output reg  [1:0]  wb_wb_sel
);
    always @(posedge clk) begin
        if (!rst_n) begin
            wb_alu_result<=0; wb_read_data<=0; wb_pc_plus4<=0;
            wb_rd<=0; wb_reg_write<=0; wb_wb_sel<=0;
        end else if (!stall) begin
            wb_alu_result<=mem_alu_result; wb_read_data<=mem_read_data;
            wb_pc_plus4<=mem_pc_plus4; wb_rd<=mem_rd;
            wb_reg_write<=mem_reg_write; wb_wb_sel<=mem_wb_sel;
        end
    end
endmodule
