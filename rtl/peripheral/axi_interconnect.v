module axi_interconnect (
    input  wire        clk, rst_n,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_we,
    input  wire        cpu_req,
    input  wire [2:0]  cpu_funct3,
    output reg  [31:0] cpu_rdata,
    output wire        cpu_stall,
    output reg  [31:0] m_awaddr,
    output reg         m_awvalid,
    input  wire        m_awready,
    output reg  [31:0] m_wdata,
    output reg  [3:0]  m_wstrb,
    output reg         m_wvalid,
    input  wire        m_wready,
    input  wire [1:0]  m_bresp,
    input  wire        m_bvalid,
    output reg         m_bready,
    output reg  [31:0] m_araddr,
    output reg         m_arvalid,
    input  wire        m_arready,
    input  wire [31:0] m_rdata,
    input  wire [1:0]  m_rresp,
    input  wire        m_rvalid,
    output reg         m_rready
);
    localparam IDLE=3'd0,AWADDR=3'd1,WDATA=3'd2,BRESP=3'd3,ARADDR=3'd4,RDATA=3'd5,DONE=3'd6;
    reg [2:0]  state;
    reg [31:0] addr_lat, wdata_lat;
    reg        we_lat, busy;
    assign cpu_stall = busy;
    always @(posedge clk) begin
        if (!rst_n) begin
            state<=IDLE; busy<=0;
            m_awvalid<=0; m_wvalid<=0; m_bready<=0;
            m_arvalid<=0; m_rready<=0; cpu_rdata<=0;
            m_awaddr<=0; m_wdata<=0; m_wstrb<=4'hF; m_araddr<=0;
        end else case (state)
            IDLE: begin
                busy<=0;
                if (cpu_req) begin
                    addr_lat<=cpu_addr; wdata_lat<=cpu_wdata; we_lat<=cpu_we;
                    busy<=1;
                    state<=cpu_we ? AWADDR : ARADDR;
                end
            end
            AWADDR: begin
                m_awaddr<=addr_lat; m_awvalid<=1;
                if (m_awready) begin m_awvalid<=0; state<=WDATA; end
            end
            WDATA: begin
                m_wdata<=wdata_lat; m_wstrb<=4'hF; m_wvalid<=1;
                if (m_wready) begin m_wvalid<=0; m_bready<=1; state<=BRESP; end
            end
            BRESP: begin
                if (m_bvalid) begin m_bready<=0; busy<=0; state<=DONE; end
            end
            ARADDR: begin
                m_araddr<=addr_lat; m_arvalid<=1;
                if (m_arready) begin m_arvalid<=0; m_rready<=1; state<=RDATA; end
            end
            RDATA: begin
                if (m_rvalid) begin
                    cpu_rdata<=m_rdata; m_rready<=0; busy<=0; state<=DONE;
                end
            end
            DONE: begin busy<=0; state<=IDLE; end
            default: state<=IDLE;
        endcase
    end
endmodule