// ============================================================
// dcache.v — Direct-Mapped Data Cache (Write-Back)
//
// Parameters match icache.v. Write-back policy:
//   - On write hit:  update cache only, set dirty bit
//   - On write miss: allocate line (fetch from mem), then write
//   - On eviction:   if dirty, write line back to memory first
//
// Address breakdown (32-bit):
//   [31:10] Tag    (22 bits)
//   [9:4]   Index  (6 bits)
//   [3:2]   Offset (2 bits)
//   [1:0]   Byte   (handled by mem_funct3 in CPU)
//
// FSM: IDLE → WRITEBACK → FILL → IDLE
// ============================================================

module dcache #(
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

    // CPU interface (from MEM stage)
    input  wire [ADDR_WIDTH-1:0] cpu_addr,
    input  wire [DATA_WIDTH-1:0] cpu_wdata,
    input  wire                  cpu_we,       // 1 = store
    input  wire                  cpu_req,      // 1 = load or store
    input  wire [2:0]            cpu_funct3,
    output reg  [DATA_WIDTH-1:0] cpu_rdata,
    output reg                   cpu_stall,    // 1 = pipeline must stall

    // Memory interface
    output reg  [ADDR_WIDTH-1:0] mem_addr,
    output reg  [DATA_WIDTH-1:0] mem_wdata,
    output reg                   mem_we,
    output reg                   mem_req,
    input  wire [DATA_WIDTH-1:0] mem_rdata,
    input  wire                  mem_valid
);

    // ---- Cache storage ----
    reg [TAG_BITS-1:0]   tag_array  [0:NUM_LINES-1];
    reg [DATA_WIDTH-1:0] data_array [0:NUM_LINES-1][0:WORDS_LINE-1];
    reg                  valid_array[0:NUM_LINES-1];
    reg                  dirty_array[0:NUM_LINES-1];

    // ---- Address decomposition ----
    wire [OFFSET_BITS-1:0] offset = cpu_addr[OFFSET_BITS+1:2];
    wire [INDEX_BITS-1:0]  index  = cpu_addr[INDEX_BITS+OFFSET_BITS+1:OFFSET_BITS+2];
    wire [TAG_BITS-1:0]    tag    = cpu_addr[ADDR_WIDTH-1:INDEX_BITS+OFFSET_BITS+2];

    wire hit   = valid_array[index] && (tag_array[index] == tag);
    wire dirty = dirty_array[index] && valid_array[index];

    // ---- FSM ----
    localparam IDLE      = 2'b00;
    localparam WRITEBACK = 2'b01;
    localparam FILL      = 2'b10;

    reg [1:0]              state;
    reg [OFFSET_BITS-1:0]  wb_word;   // writeback word counter
    reg [OFFSET_BITS-1:0]  fill_word; // fill word counter
    reg [ADDR_WIDTH-1:0]   miss_base; // base of missing line
    reg [ADDR_WIDTH-1:0]   wb_base;   // base address of dirty line being evicted

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            mem_req <= 1'b0; mem_we <= 1'b0;
            for (i = 0; i < NUM_LINES; i = i+1) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
            end
        end else begin
            case (state)

                IDLE: begin
                    mem_req <= 1'b0; mem_we <= 1'b0;
                    if (cpu_req) begin
                        if (hit) begin
                            // Write hit: update cache, set dirty
                            if (cpu_we) begin
                                data_array[index][offset] <= apply_write(
                                    data_array[index][offset], cpu_wdata, cpu_funct3, cpu_addr[1:0]);
                                dirty_array[index] <= 1'b1;
                            end
                            // Read hit: output driven combinationally below
                        end else begin
                            // Miss: need to fetch. If dirty, writeback first.
                            miss_base <= {cpu_addr[ADDR_WIDTH-1:OFFSET_BITS+2], {(OFFSET_BITS+2){1'b0}}};
                            if (dirty) begin
                                wb_base  <= {tag_array[index], index, {(OFFSET_BITS+2){1'b0}}};
                                wb_word  <= 0;
                                mem_addr <= {tag_array[index], index, {(OFFSET_BITS+2){1'b0}}};
                                mem_wdata<= data_array[index][0];
                                mem_we   <= 1'b1;
                                mem_req  <= 1'b1;
                                state    <= WRITEBACK;
                            end else begin
                                fill_word<= 0;
                                mem_addr <= {cpu_addr[ADDR_WIDTH-1:OFFSET_BITS+2], {(OFFSET_BITS+2){1'b0}}};
                                mem_we   <= 1'b0;
                                mem_req  <= 1'b1;
                                state    <= FILL;
                            end
                        end
                    end
                end

                WRITEBACK: begin
                    if (mem_valid) begin
                        if (wb_word == WORDS_LINE-1) begin
                            // Writeback done — start fill
                            dirty_array[index] <= 1'b0;
                            fill_word  <= 0;
                            mem_addr   <= miss_base;
                            mem_we     <= 1'b0;
                            mem_req    <= 1'b1;
                            state      <= FILL;
                        end else begin
                            wb_word   <= wb_word + 1;
                            mem_addr  <= wb_base + ((wb_word+1) << 2);
                            mem_wdata <= data_array[index][wb_word+1];
                            mem_we    <= 1'b1;
                            mem_req   <= 1'b1;
                        end
                    end else begin
                        mem_req <= 1'b0;
                    end
                end

                FILL: begin
                    if (mem_valid) begin
                        data_array[index][fill_word] <= mem_rdata;
                        if (fill_word == WORDS_LINE-1) begin
                            tag_array[index]   <= tag;
                            valid_array[index] <= 1'b1;
                            dirty_array[index] <= 1'b0;
                            state              <= IDLE;
                            mem_req            <= 1'b0;
                        end else begin
                            fill_word <= fill_word + 1;
                            mem_addr  <= miss_base + ((fill_word+1) << 2);
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

    // ---- Write merge function (apply sub-word writes) ----
    function [31:0] apply_write;
        input [31:0] old_data;
        input [31:0] wdata;
        input [2:0]  funct3;
        input [1:0]  byte_off;
        reg   [31:0] result;
        begin
            result = old_data;
            case (funct3)
                3'b000: begin // SB
                    case (byte_off)
                        2'b00: result[ 7: 0] = wdata[7:0];
                        2'b01: result[15: 8] = wdata[7:0];
                        2'b10: result[23:16] = wdata[7:0];
                        2'b11: result[31:24] = wdata[7:0];
                    endcase
                end
                3'b001: begin // SH
                    if (!byte_off[1]) result[15:0]  = wdata[15:0];
                    else              result[31:16]  = wdata[15:0];
                end
                3'b010: result = wdata; // SW
                default: result = wdata;
            endcase
            apply_write = result;
        end
    endfunction

    // ---- Combinational read output ----
    always @(*) begin
        cpu_stall = 1'b0;
        cpu_rdata = 32'b0;

        if (cpu_req) begin
            if (hit && !cpu_we) begin
                // Read hit
                cpu_rdata = read_extract(data_array[index][offset], cpu_funct3, cpu_addr[1:0]);
                cpu_stall = 1'b0;
            end else if (!hit) begin
                cpu_stall = 1'b1;  // miss: stall until fill done
            end
        end
    end

    // ---- Read extract function (load byte/halfword/word) ----
    function [31:0] read_extract;
        input [31:0] data;
        input [2:0]  funct3;
        input [1:0]  byte_off;
        reg   [31:0] result;
        reg   [7:0]  byte_val;
        reg   [15:0] half_val;
        begin
            case (funct3)
                3'b000: begin // LB
                    case (byte_off)
                        2'b00: byte_val = data[ 7: 0];
                        2'b01: byte_val = data[15: 8];
                        2'b10: byte_val = data[23:16];
                        2'b11: byte_val = data[31:24];
                        default: byte_val = 8'b0;
                    endcase
                    result = {{24{byte_val[7]}}, byte_val};
                end
                3'b001: begin // LH
                    half_val = byte_off[1] ? data[31:16] : data[15:0];
                    result   = {{16{half_val[15]}}, half_val};
                end
                3'b010: result = data; // LW
                3'b100: begin // LBU
                    case (byte_off)
                        2'b00: result = {24'b0, data[ 7: 0]};
                        2'b01: result = {24'b0, data[15: 8]};
                        2'b10: result = {24'b0, data[23:16]};
                        2'b11: result = {24'b0, data[31:24]};
                        default: result = 32'b0;
                    endcase
                end
                3'b101: begin // LHU
                    result = byte_off[1] ? {16'b0, data[31:16]} : {16'b0, data[15:0]};
                end
                default: result = data;
            endcase
            read_extract = result;
        end
    endfunction

endmodule
