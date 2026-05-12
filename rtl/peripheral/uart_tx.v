module uart_tx #(parameter CLKS_PER_BIT = 868)(
    input  wire       clk, rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_busy,
    output reg        tx
);
    localparam IDLE=2'b00, START=2'b01, DATA=2'b10, STOP=2'b11;
    reg [1:0] state; reg [9:0] clk_cnt; reg [2:0] bit_idx; reg [7:0] tx_shift;
    always @(posedge clk) begin
        if (!rst_n) begin
            state<=IDLE; tx<=1'b1; tx_busy<=0; clk_cnt<=0; bit_idx<=0; tx_shift<=0;
        end else case (state)
            IDLE: begin
                tx<=1'b1; tx_busy<=0; clk_cnt<=0; bit_idx<=0;
                if (tx_valid) begin tx_shift<=tx_data; tx_busy<=1; state<=START; end
            end
            START: begin
                tx<=1'b0;
                if (clk_cnt==CLKS_PER_BIT-1) begin clk_cnt<=0; state<=DATA; end
                else clk_cnt<=clk_cnt+1;
            end
            DATA: begin
                tx<=tx_shift[bit_idx];
                if (clk_cnt==CLKS_PER_BIT-1) begin
                    clk_cnt<=0;
                    if (bit_idx==7) begin bit_idx<=0; state<=STOP; end
                    else bit_idx<=bit_idx+1;
                end else clk_cnt<=clk_cnt+1;
            end
            STOP: begin
                tx<=1'b1;
                if (clk_cnt==CLKS_PER_BIT-1) begin clk_cnt<=0; tx_busy<=0; state<=IDLE; end
                else clk_cnt<=clk_cnt+1;
            end
        endcase
    end
endmodule