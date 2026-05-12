module axi_uart #(parameter CLKS_PER_BIT = 868)(
    input  wire        clk, rst_n,
    input  wire [31:0] s_awaddr, output reg s_awready,
    input  wire        s_awvalid,
    input  wire [31:0] s_wdata, input wire [3:0] s_wstrb,
    input  wire        s_wvalid, output reg s_wready,
    output reg  [1:0]  s_bresp, output reg s_bvalid, input wire s_bready,
    input  wire [31:0] s_araddr, input wire s_arvalid,
    output reg         s_arready, output reg [31:0] s_rdata,
    output reg  [1:0]  s_rresp, output reg s_rvalid, input wire s_rready,
    output wire        uart_tx_pin
);
    reg [7:0] tx_data_reg; reg tx_valid; wire tx_busy; wire tx_ready = !tx_busy;
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_uart_tx(
        .clk(clk),.rst_n(rst_n),.tx_data(tx_data_reg),.tx_valid(tx_valid),
        .tx_busy(tx_busy),.tx(uart_tx_pin));
    reg [31:0] aw_addr_lat; reg aw_done, w_done;
    always @(posedge clk) begin
        if (!rst_n) begin
            s_awready<=0; s_wready<=0; s_bvalid<=0; s_bresp<=0;
            tx_valid<=0; tx_data_reg<=0; aw_done<=0; w_done<=0; aw_addr_lat<=0;
        end else begin
            s_awready<=0; s_wready<=0; tx_valid<=0;
            if (s_awvalid && !aw_done) begin s_awready<=1; aw_addr_lat<=s_awaddr; aw_done<=1; end
            if (s_wvalid && !w_done) begin
                s_wready<=1; w_done<=1;
                if (!s_bvalid) begin tx_data_reg<=s_wdata[7:0]; if (tx_ready) tx_valid<=1; end
            end
            if (aw_done && w_done && !s_bvalid) begin
                s_bvalid<=1; s_bresp<=0; aw_done<=0; w_done<=0;
            end
            if (s_bvalid && s_bready) s_bvalid<=0;
        end
    end
    always @(posedge clk) begin
        if (!rst_n) begin s_arready<=0; s_rvalid<=0; s_rdata<=0; s_rresp<=0; end
        else begin
            s_arready<=0;
            if (s_arvalid && !s_rvalid) begin
                s_arready<=1; s_rvalid<=1; s_rresp<=0;
                case (s_araddr[3:0])
                    4'h0: s_rdata<={24'b0, tx_data_reg};
                    4'h4: s_rdata<={31'b0, tx_ready};
                    default: s_rdata<=32'hDEADBEEF;
                endcase
            end
            if (s_rvalid && s_rready) s_rvalid<=0;
        end
    end
endmodule