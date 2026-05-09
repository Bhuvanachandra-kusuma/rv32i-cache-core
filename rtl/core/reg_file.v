// ============================================================
// reg_file.v — RV32I Register File (Write-First)
//
// Write-first: if rd == rs1/rs2 and we=1 on same cycle,
// read returns the NEW value (bypasses the flip-flop).
// This prevents WB→ID read-after-write hazard.
// ============================================================
module reg_file (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  rs1, rs2, rd,
    input  wire [31:0] wdata,
    output wire [31:0] rdata1, rdata2
);
    reg [31:0] regs [1:31];
    integer k;
    initial begin
        for (k=1; k<32; k=k+1) regs[k] = 32'b0;
    end

    always @(posedge clk)
        if (we && rd != 5'b0) regs[rd] <= wdata;

    // Write-first read: if writing to the same register being read, return new value
    assign rdata1 = (rs1 == 5'b0)               ? 32'b0   :
                    (we && rd == rs1 && rd != 0) ? wdata   :
                                                   regs[rs1];
    assign rdata2 = (rs2 == 5'b0)               ? 32'b0   :
                    (we && rd == rs2 && rd != 0) ? wdata   :
                                                   regs[rs2];
endmodule
