// ============================================================
// sram_model.v — Behavioral SRAM for Simulation
// Single-cycle request latching: req goes high for one cycle,
// valid returns after LATENCY cycles.
// ============================================================
module sram_model #(
    parameter DEPTH        = 16384,
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 32,
    parameter LATENCY      = 2,
    parameter MEM_INIT_FILE= ""
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [ADDR_WIDTH-1:0] a_addr,
    input  wire                  a_req,
    output reg  [DATA_WIDTH-1:0] a_rdata,
    output reg                   a_valid,
    input  wire [ADDR_WIDTH-1:0] b_addr,
    input  wire [DATA_WIDTH-1:0] b_wdata,
    input  wire                  b_we,
    input  wire                  b_req,
    output reg  [DATA_WIDTH-1:0] b_rdata,
    output reg                   b_valid
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer k;
    initial begin
        for (k=0; k<DEPTH; k=k+1) mem[k]=32'h0000_0013; // NOP fill
        if (MEM_INIT_FILE != "")
            $readmemh(MEM_INIT_FILE, mem);
    end

    // Port A — latch req, count latency, return valid
    reg [3:0]              a_cnt;
    reg                    a_pending;
    reg [ADDR_WIDTH-1:0]   a_lat_addr;
    always @(posedge clk) begin
        if (!rst_n) begin a_valid<=0; a_cnt<=0; a_pending<=0; end
        else begin
            a_valid <= 0;
            if (a_req && !a_pending) begin
                a_lat_addr <= a_addr;
                a_pending  <= 1;
                a_cnt      <= 0;
            end
            if (a_pending) begin
                if (a_cnt == LATENCY-1) begin
                    a_rdata  <= mem[a_lat_addr[ADDR_WIDTH-1:2] % DEPTH];
                    a_valid  <= 1;
                    a_pending<= 0;
                    a_cnt    <= 0;
                end else a_cnt <= a_cnt + 1;
            end
        end
    end

    // Port B
    reg [3:0]              b_cnt;
    reg                    b_pending;
    reg [ADDR_WIDTH-1:0]   b_lat_addr;
    reg [DATA_WIDTH-1:0]   b_lat_wdata;
    reg                    b_lat_we;
    always @(posedge clk) begin
        if (!rst_n) begin b_valid<=0; b_cnt<=0; b_pending<=0; end
        else begin
            b_valid <= 0;
            if (b_req && !b_pending) begin
                b_lat_addr  <= b_addr;
                b_lat_wdata <= b_wdata;
                b_lat_we    <= b_we;
                b_pending   <= 1;
                b_cnt       <= 0;
            end
            if (b_pending) begin
                if (b_cnt == LATENCY-1) begin
                    if (b_lat_we)
                        mem[b_lat_addr[ADDR_WIDTH-1:2] % DEPTH] <= b_lat_wdata;
                    else
                        b_rdata <= mem[b_lat_addr[ADDR_WIDTH-1:2] % DEPTH];
                    b_valid  <= 1;
                    b_pending<= 0;
                    b_cnt    <= 0;
                end else b_cnt <= b_cnt + 1;
            end
        end
    end
endmodule
