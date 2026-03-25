// Testbench for OBI to AXI4-Lite Adapter
`timescale 1ns / 1ps

module tb_obi_axil_adapter;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10;

    logic clk;
    logic rst_n;

    // OBI signals
    logic                      obi_req;
    logic                      obi_gnt;
    logic                      obi_rvalid;
    logic                      obi_we;
    logic [DATA_WIDTH/8-1:0]   obi_be;
    logic [ADDR_WIDTH-1:0]     obi_addr;
    logic [DATA_WIDTH-1:0]     obi_wdata;
    logic [DATA_WIDTH-1:0]     obi_rdata;
    logic                      obi_err;

    // AXI4-Lite signals
    logic [ADDR_WIDTH-1:0]     m_awaddr;
    logic                      m_awvalid;
    logic                      m_awready;
    logic [DATA_WIDTH-1:0]     m_wdata;
    logic [DATA_WIDTH/8-1:0]   m_wstrb;
    logic                      m_wvalid;
    logic                      m_wready;
    logic [1:0]                m_bresp;
    logic                      m_bvalid;
    logic                      m_bready;
    logic [ADDR_WIDTH-1:0]     m_araddr;
    logic                      m_arvalid;
    logic                      m_arready;
    logic [DATA_WIDTH-1:0]     m_rdata;
    logic [1:0]                m_rresp;
    logic                      m_rvalid;
    logic                      m_rready;

    // Test tracking
    integer pass_count = 0;
    integer fail_count = 0;

    // ---------------------------------------------------------------
    // DUT
    // ---------------------------------------------------------------
    obi_axil_adapter #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .obi_req_i    (obi_req),
        .obi_gnt_o    (obi_gnt),
        .obi_rvalid_o (obi_rvalid),
        .obi_we_i     (obi_we),
        .obi_be_i     (obi_be),
        .obi_addr_i   (obi_addr),
        .obi_wdata_i  (obi_wdata),
        .obi_rdata_o  (obi_rdata),
        .obi_err_o    (obi_err),
        .m_awaddr     (m_awaddr),
        .m_awvalid    (m_awvalid),
        .m_awready    (m_awready),
        .m_wdata      (m_wdata),
        .m_wstrb      (m_wstrb),
        .m_wvalid     (m_wvalid),
        .m_wready     (m_wready),
        .m_bresp      (m_bresp),
        .m_bvalid     (m_bvalid),
        .m_bready     (m_bready),
        .m_araddr     (m_araddr),
        .m_arvalid    (m_arvalid),
        .m_arready    (m_arready),
        .m_rdata      (m_rdata),
        .m_rresp      (m_rresp),
        .m_rvalid     (m_rvalid),
        .m_rready     (m_rready)
    );

    // ---------------------------------------------------------------
    // Clock generation
    // ---------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---------------------------------------------------------------
    // AXI slave responder — immediate accept, 1-cycle response
    // ---------------------------------------------------------------
    // AW/W accept immediately
    logic aw_pending_q, w_pending_q;
    logic [ADDR_WIDTH-1:0] aw_addr_q;
    logic [DATA_WIDTH-1:0] w_data_q;

    // Simple memory for read-back
    reg [DATA_WIDTH-1:0] mem [0:15];

    // AW channel
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_awready <= 1'b1;
        end else begin
            m_awready <= 1'b1;
        end
    end

    // W channel
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_wready <= 1'b1;
        end else begin
            m_wready <= 1'b1;
        end
    end

    // B channel — respond after AW+W both accepted
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_bvalid <= 1'b0;
            m_bresp  <= 2'b00;
        end else begin
            if (m_bvalid && m_bready) begin
                m_bvalid <= 1'b0;
            end
            if (m_awvalid && m_awready && m_wvalid && m_wready) begin
                m_bvalid <= 1'b1;
                m_bresp  <= 2'b00;
                mem[m_awaddr[5:2]] <= m_wdata;
            end
        end
    end

    // AR channel
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_arready <= 1'b1;
        end else begin
            m_arready <= 1'b1;
        end
    end

    // R channel — respond 1 cycle after AR
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_rvalid <= 1'b0;
            m_rdata  <= '0;
            m_rresp  <= 2'b00;
        end else begin
            if (m_rvalid && m_rready) begin
                m_rvalid <= 1'b0;
            end
            if (m_arvalid && m_arready) begin
                m_rvalid <= 1'b1;
                m_rdata  <= mem[m_araddr[5:2]];
                m_rresp  <= 2'b00;
            end
        end
    end

    // ---------------------------------------------------------------
    // Tasks
    // ---------------------------------------------------------------
    task obi_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data, input [3:0] be_val);
        @(posedge clk);
        obi_req   <= 1'b1;
        obi_we    <= 1'b1;
        obi_addr  <= addr;
        obi_wdata <= data;
        obi_be    <= be_val;
        // Wait for grant
        @(posedge clk);
        while (!obi_gnt) @(posedge clk);
        obi_req <= 1'b0;
        obi_we  <= 1'b0;
        // Wait for rvalid
        @(posedge clk);
        while (!obi_rvalid) @(posedge clk);
    endtask

    task obi_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
        @(posedge clk);
        obi_req  <= 1'b1;
        obi_we   <= 1'b0;
        obi_addr <= addr;
        obi_be   <= 4'hF;
        // Wait for grant
        @(posedge clk);
        while (!obi_gnt) @(posedge clk);
        obi_req <= 1'b0;
        // Wait for rvalid
        @(posedge clk);
        while (!obi_rvalid) @(posedge clk);
        data = obi_rdata;
    endtask

    task check(input string name, input [DATA_WIDTH-1:0] got, input [DATA_WIDTH-1:0] exp);
        if (got === exp) begin
            $display("[PASS] %s: 0x%08x", name, got);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %s: got 0x%08x, exp 0x%08x", name, got, exp);
            fail_count = fail_count + 1;
        end
    endtask

    // ---------------------------------------------------------------
    // Main test
    // ---------------------------------------------------------------
    reg [DATA_WIDTH-1:0] rd_data;

    initial begin
        $dumpfile("tb_obi_axil_adapter.vcd");
        $dumpvars(0, tb_obi_axil_adapter);

        // Initialize
        obi_req   = 1'b0;
        obi_we    = 1'b0;
        obi_be    = 4'h0;
        obi_addr  = '0;
        obi_wdata = '0;

        // Initialize memory
        for (integer i = 0; i < 16; i++) mem[i] = '0;

        // Reset
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // Test 1: Simple write
        $display("\n--- Test 1: Simple write ---");
        obi_write(32'h0000_0000, 32'hDEAD_BEEF, 4'hF);

        // Test 2: Read back
        $display("--- Test 2: Read back ---");
        obi_read(32'h0000_0000, rd_data);
        check("read_back", rd_data, 32'hDEAD_BEEF);

        // Test 3: Write then read different address
        $display("--- Test 3: Write + read different addr ---");
        obi_write(32'h0000_0004, 32'hCAFE_BABE, 4'hF);
        obi_read(32'h0000_0004, rd_data);
        check("read_addr4", rd_data, 32'hCAFE_BABE);

        // Test 4: Multiple writes then reads
        $display("--- Test 4: Multiple writes then reads ---");
        obi_write(32'h0000_0008, 32'h1111_1111, 4'hF);
        obi_write(32'h0000_000C, 32'h2222_2222, 4'hF);
        obi_read(32'h0000_0008, rd_data);
        check("multi_rd_08", rd_data, 32'h1111_1111);
        obi_read(32'h0000_000C, rd_data);
        check("multi_rd_0c", rd_data, 32'h2222_2222);

        // Summary
        repeat (5) @(posedge clk);
        $display("\n========================================");
        $display("  PASS: %0d  FAIL: %0d", pass_count, fail_count);
        $display("========================================");
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $finish;
    end

    // Timeout
    initial begin
        #(CLK_PERIOD * 500);
        $display("[TIMEOUT] Simulation exceeded time limit");
        $finish;
    end

endmodule
