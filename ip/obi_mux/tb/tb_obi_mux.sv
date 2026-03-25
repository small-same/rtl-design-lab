// Testbench for OBI 2-to-1 Multiplexer / Arbiter
`timescale 1ns / 1ps
`include "tb_macros.vh"

module tb_obi_mux;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10;

    logic clk;
    logic rst_n;

    // Instruction port
    logic                    instr_req;
    logic                    instr_gnt;
    logic                    instr_rvalid;
    logic [ADDR_WIDTH-1:0]   instr_addr;
    logic [DATA_WIDTH-1:0]   instr_rdata;
    logic                    instr_err;

    // Data port
    logic                    data_req;
    logic                    data_gnt;
    logic                    data_rvalid;
    logic                    data_we;
    logic [DATA_WIDTH/8-1:0] data_be;
    logic [ADDR_WIDTH-1:0]   data_addr;
    logic [DATA_WIDTH-1:0]   data_wdata;
    logic [DATA_WIDTH-1:0]   data_rdata;
    logic                    data_err;

    // Merged OBI master
    logic                    obi_req;
    logic                    obi_gnt;
    logic                    obi_rvalid;
    logic                    obi_we;
    logic [DATA_WIDTH/8-1:0] obi_be;
    logic [ADDR_WIDTH-1:0]   obi_addr;
    logic [DATA_WIDTH-1:0]   obi_wdata;
    logic [DATA_WIDTH-1:0]   obi_rdata;
    logic                    obi_err;

    `TB_COUNTERS

    // ---------------------------------------------------------------
    // DUT
    // ---------------------------------------------------------------
    obi_mux #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .instr_req_i    (instr_req),
        .instr_gnt_o    (instr_gnt),
        .instr_rvalid_o (instr_rvalid),
        .instr_addr_i   (instr_addr),
        .instr_rdata_o  (instr_rdata),
        .instr_err_o    (instr_err),
        .data_req_i     (data_req),
        .data_gnt_o     (data_gnt),
        .data_rvalid_o  (data_rvalid),
        .data_we_i      (data_we),
        .data_be_i      (data_be),
        .data_addr_i    (data_addr),
        .data_wdata_i   (data_wdata),
        .data_rdata_o   (data_rdata),
        .data_err_o     (data_err),
        .obi_req_o      (obi_req),
        .obi_gnt_i      (obi_gnt),
        .obi_rvalid_i   (obi_rvalid),
        .obi_we_o       (obi_we),
        .obi_be_o       (obi_be),
        .obi_addr_o     (obi_addr),
        .obi_wdata_o    (obi_wdata),
        .obi_rdata_i    (obi_rdata),
        .obi_err_i      (obi_err)
    );

    // ---------------------------------------------------------------
    // Clock generation
    // ---------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---------------------------------------------------------------
    // Simple OBI slave responder (1-cycle grant, 1-cycle response)
    // Small memory for read-back verification
    // ---------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem [0:15];
    logic resp_pending_q;
    logic resp_we_q;
    logic [3:0] resp_addr_q;
    logic [DATA_WIDTH-1:0] resp_wdata_q;

    // Always grant immediately
    assign obi_gnt = obi_req;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            obi_rvalid   <= 1'b0;
            obi_rdata    <= '0;
            obi_err      <= 1'b0;
            resp_pending_q <= 1'b0;
        end else begin
            if (obi_req && obi_gnt) begin
                obi_rvalid <= 1'b1;
                obi_err    <= 1'b0;
                if (obi_we) begin
                    mem[obi_addr[5:2]] <= obi_wdata;
                    obi_rdata <= '0;
                end else begin
                    obi_rdata <= mem[obi_addr[5:2]];
                end
            end else begin
                obi_rvalid <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------------
    // Tasks
    // ---------------------------------------------------------------

    // Issue an instruction read and wait for response
    task automatic instr_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] rdata);
        @(posedge clk);
        instr_req  <= 1'b1;
        instr_addr <= addr;
        @(posedge clk);
        while (!instr_gnt) @(posedge clk);
        instr_req <= 1'b0;
        @(posedge clk);
        while (!instr_rvalid) @(posedge clk);
        rdata = instr_rdata;
    endtask

    // Issue a data write and wait for response
    task automatic data_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] wdata);
        @(posedge clk);
        data_req   <= 1'b1;
        data_we    <= 1'b1;
        data_be    <= 4'hF;
        data_addr  <= addr;
        data_wdata <= wdata;
        @(posedge clk);
        while (!data_gnt) @(posedge clk);
        data_req <= 1'b0;
        data_we  <= 1'b0;
        @(posedge clk);
        while (!data_rvalid) @(posedge clk);
    endtask

    // Issue a data read and wait for response
    task automatic data_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] rdata);
        @(posedge clk);
        data_req  <= 1'b1;
        data_we   <= 1'b0;
        data_be   <= 4'hF;
        data_addr <= addr;
        @(posedge clk);
        while (!data_gnt) @(posedge clk);
        data_req <= 1'b0;
        @(posedge clk);
        while (!data_rvalid) @(posedge clk);
        rdata = data_rdata;
    endtask

    // ---------------------------------------------------------------
    // Main test
    // ---------------------------------------------------------------
    reg [DATA_WIDTH-1:0] rd_data;

    initial begin
        // Initialize
        instr_req  = 1'b0;
        instr_addr = '0;
        data_req   = 1'b0;
        data_we    = 1'b0;
        data_be    = 4'h0;
        data_addr  = '0;
        data_wdata = '0;
        for (integer i = 0; i < 16; i++) mem[i] = '0;

        // Reset
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // ---- Test 1: Data write then read ----
        `TB_GROUP("Test 1: Data port write + read")
        data_write(32'h0000_0000, 32'hDEAD_BEEF);
        data_read(32'h0000_0000, rd_data);
        `TB_CHECK_EQ(rd_data, 32'hDEAD_BEEF, "data write/read addr 0")

        // ---- Test 2: Instruction read ----
        `TB_GROUP("Test 2: Instruction port read")
        // Pre-load memory for instruction read
        mem[1] = 32'h1234_5678;
        instr_read(32'h0000_0004, rd_data);
        `TB_CHECK_EQ(rd_data, 32'h1234_5678, "instr read addr 4")

        // ---- Test 3: Data priority over instruction ----
        `TB_GROUP("Test 3: Data priority arbitration")
        // Issue both requests simultaneously
        mem[2] = 32'hAAAA_AAAA;
        @(posedge clk);
        instr_req  <= 1'b1;
        instr_addr <= 32'h0000_0008;
        data_req   <= 1'b1;
        data_we    <= 1'b0;
        data_be    <= 4'hF;
        data_addr  <= 32'h0000_0000;
        @(posedge clk);
        // Data should be granted, instr should not
        `TB_CHECK(data_gnt === 1'b1,  "data_gnt asserted on contention")
        `TB_CHECK(instr_gnt === 1'b0, "instr_gnt deasserted on contention")
        // Deassert data, keep instr
        data_req <= 1'b0;
        @(posedge clk);
        // Wait for data response
        while (!data_rvalid) @(posedge clk);
        // Now instr should get granted
        @(posedge clk);
        while (!instr_gnt) @(posedge clk);
        instr_req <= 1'b0;
        @(posedge clk);
        while (!instr_rvalid) @(posedge clk);
        `TB_CHECK_EQ(instr_rdata, 32'hAAAA_AAAA, "instr read after data priority")

        // ---- Test 4: Back-to-back data transactions ----
        `TB_GROUP("Test 4: Back-to-back data transactions")
        data_write(32'h0000_000C, 32'hBBBB_BBBB);
        data_write(32'h0000_0010, 32'hCCCC_CCCC);
        data_read(32'h0000_000C, rd_data);
        `TB_CHECK_EQ(rd_data, 32'hBBBB_BBBB, "back-to-back rd addr C")
        data_read(32'h0000_0010, rd_data);
        `TB_CHECK_EQ(rd_data, 32'hCCCC_CCCC, "back-to-back rd addr 10")

        // ---- Test 5: Instruction-only traffic ----
        `TB_GROUP("Test 5: Instruction-only traffic")
        mem[5] = 32'h5555_5555;
        instr_read(32'h0000_0014, rd_data);
        `TB_CHECK_EQ(rd_data, 32'h5555_5555, "instr-only read")

        // ---- Summary ----
        repeat (5) @(posedge clk);
        `TB_SUMMARY("tb_obi_mux")
        $finish;
    end

    // ---------------------------------------------------------------
    // VCD dump control
    // ---------------------------------------------------------------
    `TB_DUMP_CONTROL(tb_obi_mux)

    // Timeout
    initial begin
        #(CLK_PERIOD * 1000);
        `TB_FATAL("Simulation exceeded time limit")
    end

endmodule
