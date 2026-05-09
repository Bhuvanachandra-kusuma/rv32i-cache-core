// ============================================================
// icache.v — Direct-Mapped Instruction Cache (Read-Only)
//
// Parameters:
//   CACHE_SIZE  = 1024 bytes  (256 words)
//   LINE_SIZE   = 16 bytes    (4 words per line)
//   NUM_LINES   = 64
//
// Address breakdown (32-bit):
//   [31:10] Tag     (22 bits)
//   [9:4]   Index   (6 bits  → 64 lines)
//   [3:2]   Offset  (2 bits  → 4 words per line)
//   [1:0]   Byte    (ignored, always word-aligned)
//
// Miss FSM: IDLE → MISS_WAIT → FILL → IDLE
// On miss: stall pipeline, fetch 4 words from main memory, fill line.
// ============================================================

module icache #(
    parameter NUM_LINES  = 64,
    parameter WORDS_LINE = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter INDEX_BITS = 6,
    parameter OFFSET_BITS= 2,
    parameter TAG_BITS   = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS - 2
) (
    input  wire                  clk,
    input  wire                  rst_n,

    // CPU interface (from IF stage)
    input  wire [ADDR_WIDTH-1:0] cpu_addr,
    input  wire                  cpu_req,      // 1 = fetch request
    output reg  [DATA_WIDTH-1:0] cpu_rdata,
    output reg                   cpu_hit,      // 1 = data valid this cycle
    output reg                   cpu_stall,    // 1 = pipeline must stall

    // Memory interface (to SRAM model)
    output reg  [ADDR_WIDTH-1:0] mem_addr,
    output reg                   mem_req,
    input  wire [DATA_WIDTH-1:0] mem_rdata,
    input  wire                  mem_valid     // 1 = mem_rdata is valid
);

    // ---- Cache storage ----
    reg [TAG_BITS-1:0]              tag_array  [0:NUM_LINES-1];
    reg [DATA_WIDTH-1:0]            data_array [0:NUM_LINES-1][0:WORDS_LINE-1];
    reg                             valid_array[0:NUM_LINES-1];

    // ---- Address decomposition ----
    wire [OFFSET_BITS-1:0] offset = cpu_addr[OFFSET_BITS+1:2];
    wire [INDEX_BITS-1:0]  index  = cpu_addr[INDEX_BITS+OFFSET_BITS+1:OFFSET_BITS+2];
    wire [TAG_BITS-1:0]    tag    = cpu_addr[ADDR_WIDTH-1:INDEX_BITS+OFFSET_BITS+2];

    // ---- Hit check ----
    wire hit = valid_array[index] && (tag_array[index] == tag);

    // ---- Miss FSM ----
    localparam IDLE      = 2'b00;
    localparam MISS_WAIT = 2'b01;
    localparam FILL      = 2'b10;

    reg [1:0]              state;
    reg [OFFSET_BITS-1:0]  fill_word;  // which word in the line we're filling
    reg [ADDR_WIDTH-1:0]   miss_addr;  // base address of the missing line

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= IDLE;
            mem_req  <= 1'b0;
            fill_word<= 0;
            for (i = 0; i < NUM_LINES; i = i+1)
                valid_array[i] <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    mem_req <= 1'b0;
                    if (cpu_req && !hit) begin
                        // Cache miss — start fill
                        miss_addr <= {cpu_addr[ADDR_WIDTH-1:OFFSET_BITS+2], {(OFFSET_BITS+2){1'b0}}};
                        fill_word <= 0;
                        state     <= MISS_WAIT;
                        mem_addr  <= {cpu_addr[ADDR_WIDTH-1:OFFSET_BITS+2], {(OFFSET_BITS+2){1'b0}}};
                        mem_req   <= 1'b1;
                    end
                end

                MISS_WAIT: begin
                    if (mem_valid) begin
                        data_array[index][fill_word] <= mem_rdata;
                        if (fill_word == WORDS_LINE-1) begin
                            // Line fully filled
                            tag_array[index]   <= tag;
                            valid_array[index] <= 1'b1;
                            state              <= IDLE;
                            mem_req            <= 1'b0;
                        end else begin
                            fill_word <= fill_word + 1;
                            mem_addr  <= miss_addr + ((fill_word+1) << 2);
                            mem_req   <= 1'b1;
                        end
                    end else begin
                        mem_req <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // ---- Combinational output ----
    always @(*) begin
        if (cpu_req && hit) begin
            cpu_rdata = data_array[index][offset];
            cpu_hit   = 1'b1;
            cpu_stall = 1'b0;
        end else if (cpu_req && !hit) begin
            cpu_rdata = 32'b0;
            cpu_hit   = 1'b0;
            cpu_stall = 1'b1;  // stall until fill completes
        end else begin
            cpu_rdata = 32'b0;
            cpu_hit   = 1'b0;
            cpu_stall = 1'b0;
        end
    end

endmodule
