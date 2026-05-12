`timescale 1ns/1ps
module tb_soc;
    reg clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    wire uart_tx_pin, result_valid;
    wire [31:0] result;

    rv32i_soc #(.MEM_INIT_FILE("sim/program.hex")) dut(
        .clk(clk),.rst_n(rst_n),
        .result(result),.result_valid(result_valid),
        .uart_tx_pin(uart_tx_pin));

    initial begin $dumpfile("sim/tb_soc.vcd"); $dumpvars(0,tb_soc); end

    localparam CLKS_PER_BIT = 868;
    reg [31:0] uart_cnt  = 0;
    reg [2:0]  uart_bidx = 0;
    reg [7:0]  uart_rxbyte = 0;
    reg        uart_rxing = 0;
    reg        uart_done  = 0;
    reg [7:0]  uart_byte  = 0;
    reg        tx_prev    = 1;

    always @(posedge clk) begin
        tx_prev <= uart_tx_pin;
        if (!rst_n) begin
            tx_prev <= 1; uart_rxing <= 0; uart_done <= 0;
        end else begin
            if (tx_prev===1'b1 && uart_tx_pin===1'b0 && !uart_rxing && !uart_done) begin
                uart_rxing <= 1; uart_cnt <= 0; uart_bidx <= 0; uart_rxbyte <= 0;
            end
            if (uart_rxing) begin
                uart_cnt <= uart_cnt + 1;
                if (uart_cnt == (CLKS_PER_BIT/2 + (uart_bidx+1)*CLKS_PER_BIT)) begin
                    if (uart_bidx < 8) begin
                        uart_rxbyte[uart_bidx] <= uart_tx_pin;
                        uart_bidx <= uart_bidx + 1;
                        if (uart_bidx == 7) begin
                            uart_byte  <= {uart_tx_pin, uart_rxbyte[6:0]};
                            uart_done  <= 1;
                            uart_rxing <= 0;
                        end
                    end
                end
            end
        end
    end

    integer cycle_count=0, icache_hits=0, icache_misses=0;
    integer dcache_hits=0, dcache_misses=0;
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count+1;
            if (dut.u_icache.cpu_req &&  dut.u_icache.cpu_hit)  icache_hits   <= icache_hits+1;
            if (dut.u_icache.cpu_req && !dut.u_icache.cpu_hit)  icache_misses <= icache_misses+1;
            if (dut.u_dcache.cpu_req && !dut.u_dcache.cpu_stall) dcache_hits  <= dcache_hits+1;
            if (dut.u_dcache.cpu_req &&  dut.u_dcache.cpu_stall) dcache_misses<= dcache_misses+1;
        end
    end

    task check;
        input [255:0] label; input condition;
        begin
            if (condition) $display("  PASS  %s", label);
            else           $display("  FAIL  %s", label);
        end
    endtask

    initial begin
        $display("\n=== rv32i-cache-core + UART SoC Test ===\n");
        rst_n=0; repeat(4) @(posedge clk); rst_n=1;
        $display("--- Reset released ---");
        repeat(15000) @(posedge clk);

        $display("\n--- Correctness ---");
        check("x1 = 55 (sum 1..10)",         dut.u_core.u_rf.regs[1] === 32'd55);
        check("x4 = 0x400 (store addr)",     dut.u_core.u_rf.regs[4] === 32'h400);
        check("x5 = 0x10000000 (UART base)", dut.u_core.u_rf.regs[5] === 32'h10000000);
        check("x6 = 0x48 (ASCII H)",         dut.u_core.u_rf.regs[6] === 32'h48);
        check("x7 = 1 (STATUS ready)",       dut.u_core.u_rf.regs[7] === 32'd1);
        check("UART received byte = H",      uart_byte === 8'h48);
        check("UART transmission complete",  uart_done === 1'b1);

        $display("\n--- Cache Performance ---");
        check("I$ recorded hits",   icache_hits   > 0);
        check("I$ recorded misses", icache_misses > 0);

        $display("\n--- Performance Metrics ---");
        $display("  Total cycles  : %0d", cycle_count);
        $display("  I$ hits       : %0d", icache_hits);
        $display("  I$ misses     : %0d", icache_misses);
        $display("  D$ hits       : %0d", dcache_hits);
        $display("  D$ misses     : %0d", dcache_misses);
        if (icache_hits+icache_misses > 0)
            $display("  I$ hit rate   : %0d%%", 100*icache_hits/(icache_hits+icache_misses));

        $display("\n=== Test complete ===\n");
        $finish;
    end
endmodule
