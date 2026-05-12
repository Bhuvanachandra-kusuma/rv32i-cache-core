`timescale 1ns/1ps
module rv32i_soc #(parameter MEM_INIT_FILE = "program.hex")(
    input  wire        clk, rst_n,
    output wire [31:0] result,
    output wire        result_valid,
    output wire        uart_tx_pin
);
    wire [31:0] cpu_imem_addr, cpu_imem_data;
    wire        cpu_imem_req,  cpu_imem_valid;
    wire [31:0] cpu_dmem_addr, cpu_dmem_wdata;
    wire        cpu_dmem_we,   cpu_dmem_req;
    wire [2:0]  cpu_dmem_funct3;
    wire uart_access = (cpu_dmem_addr[31:28] == 4'h1) && cpu_dmem_req;
    wire [31:0] dcache_rdata;
    wire        dcache_stall;
    wire [31:0] interconnect_rdata;
    wire        interconnect_stall;
    wire [31:0] cpu_dmem_rdata = uart_access ? interconnect_rdata : dcache_rdata;
    wire        cpu_dmem_stall = uart_access ? interconnect_stall :
                                 (!uart_access && cpu_dmem_req) ? dcache_stall : 1'b0;
    wire [31:0] ic_mem_addr, ic_mem_rdata;
    wire        ic_mem_req,  ic_mem_valid;
    wire [31:0] dc_mem_addr, dc_mem_wdata, dc_mem_rdata;
    wire        dc_mem_we,   dc_mem_req,   dc_mem_valid;
    wire [31:0] m_awaddr, m_wdata, m_araddr, m_rdata;
    wire        m_awvalid, m_awready, m_wvalid, m_wready;
    wire [3:0]  m_wstrb;
    wire [1:0]  m_bresp, m_rresp;
    wire        m_bvalid, m_bready, m_arvalid, m_arready, m_rvalid, m_rready;
    rv32i_pipeline_core u_core(
        .clk(clk),.rst_n(rst_n),
        .imem_addr(cpu_imem_addr),.imem_data(cpu_imem_data),
        .imem_valid(cpu_imem_valid),.imem_req(cpu_imem_req),
        .dmem_addr(cpu_dmem_addr),.dmem_wdata(cpu_dmem_wdata),
        .dmem_we(cpu_dmem_we),.dmem_funct3(cpu_dmem_funct3),
        .dmem_req(cpu_dmem_req),.dmem_rdata(cpu_dmem_rdata),
        .dmem_stall(cpu_dmem_stall));
    icache u_icache(
        .clk(clk),.rst_n(rst_n),
        .cpu_addr(cpu_imem_addr),.cpu_req(cpu_imem_req),
        .cpu_rdata(cpu_imem_data),.cpu_hit(cpu_imem_valid),.cpu_stall(),
        .mem_addr(ic_mem_addr),.mem_req(ic_mem_req),
        .mem_rdata(ic_mem_rdata),.mem_valid(ic_mem_valid));
    dcache u_dcache(
        .clk(clk),.rst_n(rst_n),
        .cpu_addr(cpu_dmem_addr),.cpu_wdata(cpu_dmem_wdata),
        .cpu_we(cpu_dmem_we && !uart_access),
        .cpu_req(cpu_dmem_req && !uart_access),
        .cpu_funct3(cpu_dmem_funct3),
        .cpu_rdata(dcache_rdata),.cpu_stall(dcache_stall),
        .mem_addr(dc_mem_addr),.mem_wdata(dc_mem_wdata),
        .mem_we(dc_mem_we),.mem_req(dc_mem_req),
        .mem_rdata(dc_mem_rdata),.mem_valid(dc_mem_valid));
    axi_interconnect u_interconnect(
        .clk(clk),.rst_n(rst_n),
        .cpu_addr(cpu_dmem_addr),.cpu_wdata(cpu_dmem_wdata),
        .cpu_we(cpu_dmem_we),.cpu_req(uart_access),
        .cpu_funct3(cpu_dmem_funct3),
        .cpu_rdata(interconnect_rdata),.cpu_stall(interconnect_stall),
        .m_awaddr(m_awaddr),.m_awvalid(m_awvalid),.m_awready(m_awready),
        .m_wdata(m_wdata),.m_wstrb(m_wstrb),.m_wvalid(m_wvalid),.m_wready(m_wready),
        .m_bresp(m_bresp),.m_bvalid(m_bvalid),.m_bready(m_bready),
        .m_araddr(m_araddr),.m_arvalid(m_arvalid),.m_arready(m_arready),
        .m_rdata(m_rdata),.m_rresp(m_rresp),.m_rvalid(m_rvalid),.m_rready(m_rready));
    axi_uart u_uart(
        .clk(clk),.rst_n(rst_n),
        .s_awaddr(m_awaddr),.s_awvalid(m_awvalid),.s_awready(m_awready),
        .s_wdata(m_wdata),.s_wstrb(m_wstrb),.s_wvalid(m_wvalid),.s_wready(m_wready),
        .s_bresp(m_bresp),.s_bvalid(m_bvalid),.s_bready(m_bready),
        .s_araddr(m_araddr),.s_arvalid(m_arvalid),.s_arready(m_arready),
        .s_rdata(m_rdata),.s_rresp(m_rresp),.s_rvalid(m_rvalid),.s_rready(m_rready),
        .uart_tx_pin(uart_tx_pin));
    sram_model #(.MEM_INIT_FILE(MEM_INIT_FILE),.LATENCY(2)) u_sram(
        .clk(clk),.rst_n(rst_n),
        .a_addr(ic_mem_addr),.a_req(ic_mem_req),
        .a_rdata(ic_mem_rdata),.a_valid(ic_mem_valid),
        .b_addr(dc_mem_addr),.b_wdata(dc_mem_wdata),
        .b_we(dc_mem_we),.b_req(dc_mem_req),
        .b_rdata(dc_mem_rdata),.b_valid(dc_mem_valid));
    assign result       = u_core.wb__write_data;
    assign result_valid = u_core.wb__reg_write;
endmodule