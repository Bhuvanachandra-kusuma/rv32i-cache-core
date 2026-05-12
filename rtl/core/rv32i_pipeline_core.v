module rv32i_pipeline_core (
    input  wire        clk, rst_n,
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,
    input  wire        imem_valid,
    output wire        imem_req,
    output wire [31:0] dmem_addr, dmem_wdata,
    output wire        dmem_we,
    output wire [2:0]  dmem_funct3,
    output wire        dmem_req,
    input  wire [31:0] dmem_rdata,
    input  wire        dmem_stall
);
    wire stall_if, stall_id, flush_if_id, flush_id_ex;
    wire load_use_stall = stall_if;
    wire icache_stall = !imem_valid;
    wire cache_stall  = icache_stall || dmem_stall;
    wire front_stall  = load_use_stall || cache_stall;
    wire back_stall   = cache_stall;

    wire ex__branch_taken;
    wire [31:0] ex__branch_target;

    reg [31:0] pc;
    always @(posedge clk) begin
        if      (!rst_n)           pc <= 32'h0;
        else if (ex__branch_taken) pc <= ex__branch_target;
        else if (!front_stall)     pc <= pc + 4;
    end
    assign imem_addr = pc;
    assign imem_req  = 1'b1;

    wire [31:0] id__pc, id__instr;
    if_id_reg u_if_id(.clk(clk),.rst_n(rst_n),
        .stall(front_stall),.flush(flush_if_id || ex__branch_taken),
        .if_pc(pc),.if_instr(imem_data),.id_pc(id__pc),.id_instr(id__instr));

    wire [4:0]  id__rs1=id__instr[19:15], id__rs2=id__instr[24:20], id__rd=id__instr[11:7];
    wire [6:0]  id__opcode=id__instr[6:0];
    wire [2:0]  id__funct3=id__instr[14:12];
    wire [31:0] id__imm;
    imm_gen u_imm(.instr(id__instr),.imm(id__imm));

    wire [3:0] id__alu_op;
    wire id__alu_src,id__branch,id__jump,id__mem_read,id__mem_write,id__reg_write;
    wire [1:0] id__wb_sel;
    control u_ctrl(.opcode(id__opcode),.funct3(id__funct3),.funct7_5(id__instr[30]),
        .alu_op(id__alu_op),.alu_src(id__alu_src),.branch(id__branch),.jump(id__jump),
        .mem_read(id__mem_read),.mem_write(id__mem_write),
        .reg_write(id__reg_write),.wb_sel(id__wb_sel));

    wire [31:0] wb__write_data,wb__alu_result,wb__read_data,wb__pc_plus4;
    wire [4:0]  wb__rd; wire wb__reg_write; wire [1:0] wb__wb_sel;
    assign wb__write_data=(wb__wb_sel==2'b01)?wb__read_data:
                          (wb__wb_sel==2'b10)?wb__pc_plus4:wb__alu_result;

    wire [31:0] id__rs1_data, id__rs2_data;
    reg_file u_rf(.clk(clk),.we(wb__reg_write && !back_stall),
        .rs1(id__rs1),.rs2(id__rs2),.rd(wb__rd),.wdata(wb__write_data),
        .rdata1(id__rs1_data),.rdata2(id__rs2_data));

    wire [31:0] ex__pc,ex__rs1_data,ex__rs2_data,ex__imm;
    wire [4:0]  ex__rs1,ex__rs2,ex__rd;
    wire [3:0]  ex__alu_op;
    wire ex__alu_src,ex__branch,ex__jump,ex__mem_read,ex__mem_write,ex__reg_write;
    wire [2:0]  ex__mem_funct3; wire [1:0] ex__wb_sel;
    id_ex_reg u_id_ex(.clk(clk),.rst_n(rst_n),
        .flush(flush_id_ex || ex__branch_taken),.stall(front_stall),
        .id_pc(id__pc),.id_rs1_data(id__rs1_data),.id_rs2_data(id__rs2_data),
        .id_imm(id__imm),.id_rs1(id__rs1),.id_rs2(id__rs2),.id_rd(id__rd),
        .id_alu_op(id__alu_op),.id_alu_src(id__alu_src),
        .id_branch(id__branch),.id_jump(id__jump),
        .id_mem_read(id__mem_read),.id_mem_write(id__mem_write),.id_mem_funct3(id__funct3),
        .id_reg_write(id__reg_write),.id_wb_sel(id__wb_sel),
        .ex_pc(ex__pc),.ex_rs1_data(ex__rs1_data),.ex_rs2_data(ex__rs2_data),
        .ex_imm(ex__imm),.ex_rs1(ex__rs1),.ex_rs2(ex__rs2),.ex_rd(ex__rd),
        .ex_alu_op(ex__alu_op),.ex_alu_src(ex__alu_src),
        .ex_branch(ex__branch),.ex_jump(ex__jump),
        .ex_mem_read(ex__mem_read),.ex_mem_write(ex__mem_write),.ex_mem_funct3(ex__mem_funct3),
        .ex_reg_write(ex__reg_write),.ex_wb_sel(ex__wb_sel));

    wire [31:0] mem__alu_result,mem__rs2_data,mem__pc_plus4;
    wire [4:0]  mem__rd;
    wire mem__mem_read,mem__mem_write,mem__reg_write;
    wire [2:0]  mem__mem_funct3; wire [1:0] mem__wb_sel;
    wire [31:0] mem__branch_target; wire mem__branch_taken;

    wire [1:0] fwd_a,fwd_b;
    forwarding_unit u_fwd(.ex_rs1(ex__rs1),.ex_rs2(ex__rs2),
        .mem_reg_write(mem__reg_write),.mem_rd(mem__rd),
        .wb_reg_write(wb__reg_write),.wb_rd(wb__rd),
        .forward_a(fwd_a),.forward_b(fwd_b));

    wire [31:0] alu_in_a=(fwd_a==2'b10)?mem__alu_result:(fwd_a==2'b01)?wb__write_data:ex__rs1_data;
    wire [31:0] alu_in_b_fwd=(fwd_b==2'b10)?mem__alu_result:(fwd_b==2'b01)?wb__write_data:ex__rs2_data;
    wire [31:0] alu_a_final=(id__opcode==7'b0010111)?ex__pc:alu_in_a;
    wire [31:0] alu_in_b=ex__alu_src?ex__imm:alu_in_b_fwd;

    wire [31:0] ex__alu_result; wire ex__zero;
    alu u_alu(.alu_op(ex__alu_op),.a(alu_a_final),.b(alu_in_b),
              .result(ex__alu_result),.zero(ex__zero));

    branch_unit u_branch(.rs1_data(alu_in_a),.rs2_data(alu_in_b_fwd),
        .funct3(ex__mem_funct3),.branch(ex__branch),.jump(ex__jump),
        .taken(ex__branch_taken));

    wire [31:0] ex__pc_plus4 = ex__pc + 4;
    assign ex__branch_target = (ex__jump && ex__alu_src) ?
                               (alu_in_a + ex__imm) & ~32'h1 : ex__pc + ex__imm;

    ex_mem_reg u_ex_mem(.clk(clk),.rst_n(rst_n),.stall(back_stall),
        .ex_alu_result(ex__alu_result),.ex_rs2_data(alu_in_b_fwd),.ex_rd(ex__rd),
        .ex_branch_taken(ex__branch_taken),.ex_branch_target(ex__branch_target),
        .ex_mem_read(ex__mem_read),.ex_mem_write(ex__mem_write),.ex_mem_funct3(ex__mem_funct3),
        .ex_reg_write(ex__reg_write),.ex_wb_sel(ex__wb_sel),.ex_pc_plus4(ex__pc_plus4),
        .mem_alu_result(mem__alu_result),.mem_rs2_data(mem__rs2_data),.mem_rd(mem__rd),
        .mem_branch_taken(mem__branch_taken),.mem_branch_target(mem__branch_target),
        .mem_mem_read(mem__mem_read),.mem_mem_write(mem__mem_write),.mem_mem_funct3(mem__mem_funct3),
        .mem_reg_write(mem__reg_write),.mem_wb_sel(mem__wb_sel),.mem_pc_plus4(mem__pc_plus4));

    assign dmem_addr   = mem__alu_result;
    assign dmem_wdata  = mem__rs2_data;
    assign dmem_we     = mem__mem_write && !back_stall;
    assign dmem_funct3 = mem__mem_funct3;
    assign dmem_req    = mem__mem_read || mem__mem_write;

    mem_wb_reg u_mem_wb(.clk(clk),.rst_n(rst_n),.stall(back_stall),
        .mem_alu_result(mem__alu_result),.mem_read_data(dmem_rdata),
        .mem_pc_plus4(mem__pc_plus4),.mem_rd(mem__rd),
        .mem_reg_write(mem__reg_write),.mem_wb_sel(mem__wb_sel),
        .wb_alu_result(wb__alu_result),.wb_read_data(wb__read_data),
        .wb_pc_plus4(wb__pc_plus4),.wb_rd(wb__rd),
        .wb_reg_write(wb__reg_write),.wb_wb_sel(wb__wb_sel));

    hazard_unit u_hazard(.ex_mem_read(ex__mem_read),.ex_rd(ex__rd),
        .id_rs1(id__rs1),.id_rs2(id__rs2),
        .ex_branch_taken(ex__branch_taken),.ex_jump(ex__jump),
        .stall_if(stall_if),.stall_id(stall_id),
        .flush_id_ex(flush_id_ex),.flush_if_id(flush_if_id));
endmodule
