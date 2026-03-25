// AXI4-Lite SRAM Slave — single-port 4KB
/* verilator lint_off UNUSED */
module axi_sram #(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 32,
    parameter MEM_DEPTH     = 1024,  // 1024 x 32-bit = 4KB
    parameter MEM_INIT_FILE = ""
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // AXI4-Lite Write Address Channel
    input  logic [ADDR_WIDTH-1:0]  s_awaddr,
    input  logic                    s_awvalid,
    output logic                    s_awready,

    // AXI4-Lite Write Data Channel
    input  logic [DATA_WIDTH-1:0]  s_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_wstrb,
    input  logic                    s_wvalid,
    output logic                    s_wready,

    // AXI4-Lite Write Response Channel
    output logic [1:0]             s_bresp,
    output logic                    s_bvalid,
    input  logic                    s_bready,

    // AXI4-Lite Read Address Channel
    input  logic [ADDR_WIDTH-1:0]  s_araddr,
    input  logic                    s_arvalid,
    output logic                    s_arready,

    // AXI4-Lite Read Data Channel
    output logic [DATA_WIDTH-1:0]  s_rdata,
    output logic [1:0]             s_rresp,
    output logic                    s_rvalid,
    input  logic                    s_rready
);

    // ---------------------------------------------------------------
    // Local parameters
    // ---------------------------------------------------------------
    localparam ADDR_LSB = $clog2(DATA_WIDTH / 8); // byte offset bits
    localparam MEM_ADDR_WIDTH = $clog2(MEM_DEPTH);

    // ---------------------------------------------------------------
    // Memory array
    // ---------------------------------------------------------------
    logic [DATA_WIDTH-1:0] mem [MEM_DEPTH];

    generate
        if (MEM_INIT_FILE != "") begin : gen_mem_init
            initial begin
                $readmemh(MEM_INIT_FILE, mem);
            end
        end
    endgenerate

    // ---------------------------------------------------------------
    // Write channel state
    // ---------------------------------------------------------------
    logic aw_done_q, aw_done_d;
    logic w_done_q,  w_done_d;
    logic [ADDR_WIDTH-1:0] awaddr_q, awaddr_d;
    logic [DATA_WIDTH-1:0] wdata_q,  wdata_d;
    logic [DATA_WIDTH/8-1:0] wstrb_q, wstrb_d;

    // Write FSM
    logic s_awready_q, s_awready_d;
    logic s_wready_q,  s_wready_d;
    logic s_bvalid_q,  s_bvalid_d;

    always_comb begin
        aw_done_d   = aw_done_q;
        w_done_d    = w_done_q;
        awaddr_d    = awaddr_q;
        wdata_d     = wdata_q;
        wstrb_d     = wstrb_q;
        s_awready_d = 1'b0;
        s_wready_d  = 1'b0;
        s_bvalid_d  = s_bvalid_q;

        // Accept write address
        if (s_awvalid && !aw_done_q && !s_bvalid_q) begin
            s_awready_d = 1'b1;
            aw_done_d   = 1'b1;
            awaddr_d    = s_awaddr;
        end

        // Accept write data
        if (s_wvalid && !w_done_q && !s_bvalid_q) begin
            s_wready_d = 1'b1;
            w_done_d   = 1'b1;
            wdata_d    = s_wdata;
            wstrb_d    = s_wstrb;
        end

        // Generate write response when both received (guard with !s_bvalid_q)
        if (!s_bvalid_q &&
            (aw_done_q || (s_awvalid && !aw_done_q)) &&
            (w_done_q  || (s_wvalid  && !w_done_q))) begin
            s_bvalid_d = 1'b1;
        end

        // Clear response
        if (s_bvalid_q && s_bready) begin
            s_bvalid_d = 1'b0;
            aw_done_d  = 1'b0;
            w_done_d   = 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Read channel state
    // ---------------------------------------------------------------
    logic s_arready_q, s_arready_d;
    logic s_rvalid_q,  s_rvalid_d;
    logic [DATA_WIDTH-1:0] s_rdata_q, s_rdata_d;

    always_comb begin
        s_arready_d = 1'b0;
        s_rvalid_d  = s_rvalid_q;
        s_rdata_d   = s_rdata_q;

        // Accept read address and respond
        if (s_arvalid && !s_rvalid_q) begin
            s_arready_d = 1'b1;
            s_rvalid_d  = 1'b1;
            s_rdata_d   = mem[s_araddr[ADDR_LSB +: MEM_ADDR_WIDTH]];
        end

        // Clear read response
        if (s_rvalid_q && s_rready) begin
            s_rvalid_d = 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Sequential logic
    // ---------------------------------------------------------------
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_done_q   <= 1'b0;
            w_done_q    <= 1'b0;
            awaddr_q    <= '0;
            wdata_q     <= '0;
            wstrb_q     <= '0;
            s_awready_q <= 1'b0;
            s_wready_q  <= 1'b0;
            s_bvalid_q  <= 1'b0;
            s_arready_q <= 1'b0;
            s_rvalid_q  <= 1'b0;
            s_rdata_q   <= '0;
        end else begin
            aw_done_q   <= aw_done_d;
            w_done_q    <= w_done_d;
            awaddr_q    <= awaddr_d;
            wdata_q     <= wdata_d;
            wstrb_q     <= wstrb_d;
            s_awready_q <= s_awready_d;
            s_wready_q  <= s_wready_d;
            s_bvalid_q  <= s_bvalid_d;
            s_arready_q <= s_arready_d;
            s_rvalid_q  <= s_rvalid_d;
            s_rdata_q   <= s_rdata_d;

            // Perform memory write when both address and data are captured
            if (s_bvalid_d && !s_bvalid_q) begin
                for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                    if (wstrb_d[i]) begin
                        mem[awaddr_d[ADDR_LSB +: MEM_ADDR_WIDTH]][i*8 +: 8] <= wdata_d[i*8 +: 8];
                    end
                end
            end
        end
    end

    // ---------------------------------------------------------------
    // Output assignments
    // ---------------------------------------------------------------
    assign s_awready = s_awready_q;
    assign s_wready  = s_wready_q;
    assign s_bresp   = 2'b00; // OKAY
    assign s_bvalid  = s_bvalid_q;
    assign s_arready = s_arready_q;
    assign s_rdata   = s_rdata_q;
    assign s_rresp   = 2'b00; // OKAY
    assign s_rvalid  = s_rvalid_q;

/* verilator lint_on UNUSED */
endmodule
