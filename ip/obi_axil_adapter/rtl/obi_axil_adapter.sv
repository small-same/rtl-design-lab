// OBI to AXI4-Lite Adapter
// Converts Ibex OBI-like memory interface to AXI4-Lite master
module obi_axil_adapter #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                      clk,
    input  logic                      rst_n,

    // OBI slave interface (from Ibex)
    input  logic                      obi_req_i,
    output logic                      obi_gnt_o,
    output logic                      obi_rvalid_o,
    input  logic                      obi_we_i,
    input  logic [DATA_WIDTH/8-1:0]   obi_be_i,
    input  logic [ADDR_WIDTH-1:0]     obi_addr_i,
    input  logic [DATA_WIDTH-1:0]     obi_wdata_i,
    output logic [DATA_WIDTH-1:0]     obi_rdata_o,
    output logic                      obi_err_o,

    // AXI4-Lite master interface (to interconnect)
    output logic [ADDR_WIDTH-1:0]     m_awaddr,
    output logic                      m_awvalid,
    input  logic                      m_awready,

    output logic [DATA_WIDTH-1:0]     m_wdata,
    output logic [DATA_WIDTH/8-1:0]   m_wstrb,
    output logic                      m_wvalid,
    input  logic                      m_wready,

    input  logic [1:0]                m_bresp,
    input  logic                      m_bvalid,
    output logic                      m_bready,

    output logic [ADDR_WIDTH-1:0]     m_araddr,
    output logic                      m_arvalid,
    input  logic                      m_arready,

    input  logic [DATA_WIDTH-1:0]     m_rdata,
    input  logic [1:0]                m_rresp,
    input  logic                      m_rvalid,
    output logic                      m_rready
);

    // FSM states
    localparam [2:0] ST_IDLE    = 3'd0,
                     ST_WR_ADDR = 3'd1,
                     ST_WR_DATA = 3'd2,
                     ST_WR_RESP = 3'd3,
                     ST_RD_ADDR = 3'd4,
                     ST_RD_RESP = 3'd5;

    reg [2:0] state_q, state_d;

    // Track which AXI channels have been accepted in write path
    logic aw_done_q, aw_done_d;
    logic  w_done_q,  w_done_d;

    // Registered OBI request fields (latched on grant)
    logic [ADDR_WIDTH-1:0] addr_q;
    logic [DATA_WIDTH-1:0] wdata_q;
    logic [DATA_WIDTH/8-1:0] be_q;

    // ---------------------------------------------------------------
    // Request latch — capture OBI signals when grant is asserted
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_q  <= '0;
            wdata_q <= '0;
            be_q    <= '0;
        end else if (obi_req_i && obi_gnt_o) begin
            addr_q  <= obi_addr_i;
            wdata_q <= obi_wdata_i;
            be_q    <= obi_be_i;
        end
    end

    // ---------------------------------------------------------------
    // FSM sequential
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q   <= ST_IDLE;
            aw_done_q <= 1'b0;
            w_done_q  <= 1'b0;
        end else begin
            state_q   <= state_d;
            aw_done_q <= aw_done_d;
            w_done_q  <= w_done_d;
        end
    end

    // ---------------------------------------------------------------
    // FSM combinational
    // ---------------------------------------------------------------
    always_comb begin
        state_d   = state_q;
        aw_done_d = aw_done_q;
        w_done_d  = w_done_q;

        // OBI outputs
        obi_gnt_o    = 1'b0;
        obi_rvalid_o = 1'b0;
        obi_rdata_o  = '0;
        obi_err_o    = 1'b0;

        // AXI write address
        m_awaddr  = addr_q;
        m_awvalid = 1'b0;

        // AXI write data
        m_wdata  = wdata_q;
        m_wstrb  = be_q;
        m_wvalid = 1'b0;

        // AXI write response
        m_bready = 1'b0;

        // AXI read address
        m_araddr  = addr_q;
        m_arvalid = 1'b0;

        // AXI read data
        m_rready = 1'b0;

        case (state_q)
            // ---------------------------------------------------------
            ST_IDLE: begin
                // Accept new OBI request
                obi_gnt_o = obi_req_i;
                if (obi_req_i) begin
                    if (obi_we_i) begin
                        // Start write: assert AW and W simultaneously
                        // They will be driven next cycle from latched values
                        state_d   = ST_WR_RESP;
                        aw_done_d = 1'b0;
                        w_done_d  = 1'b0;
                    end else begin
                        // Start read: assert AR next cycle
                        state_d = ST_RD_ADDR;
                    end
                end
            end

            // ---------------------------------------------------------
            // Write: drive AW+W, wait until both accepted, then wait B
            // ---------------------------------------------------------
            ST_WR_RESP: begin
                // Drive AW if not yet accepted
                m_awvalid = ~aw_done_q;
                // Drive W if not yet accepted
                m_wvalid  = ~w_done_q;

                // Track acceptance
                if (m_awvalid && m_awready) aw_done_d = 1'b1;
                if (m_wvalid  && m_wready)  w_done_d  = 1'b1;

                // Both accepted (possibly this cycle)?
                if ((aw_done_q || (m_awvalid && m_awready)) &&
                    (w_done_q  || (m_wvalid  && m_wready))) begin
                    // Now wait for B response
                    m_bready = 1'b1;
                    if (m_bvalid) begin
                        obi_rvalid_o = 1'b1;
                        obi_err_o    = |m_bresp;
                        // Pipeline: accept next request immediately
                        obi_gnt_o = obi_req_i;
                        if (obi_req_i) begin
                            if (obi_we_i) begin
                                state_d   = ST_WR_RESP;
                                aw_done_d = 1'b0;
                                w_done_d  = 1'b0;
                            end else begin
                                state_d = ST_RD_ADDR;
                            end
                        end else begin
                            state_d = ST_IDLE;
                        end
                    end
                end
            end

            // ---------------------------------------------------------
            // Read: drive AR, wait for acceptance
            // ---------------------------------------------------------
            ST_RD_ADDR: begin
                m_arvalid = 1'b1;
                if (m_arready) begin
                    state_d = ST_RD_RESP;
                end
            end

            // ---------------------------------------------------------
            // Read: wait for R response
            // ---------------------------------------------------------
            ST_RD_RESP: begin
                m_rready = 1'b1;
                if (m_rvalid) begin
                    obi_rvalid_o = 1'b1;
                    obi_rdata_o  = m_rdata;
                    obi_err_o    = |m_rresp;
                    // Pipeline: accept next request immediately
                    obi_gnt_o = obi_req_i;
                    if (obi_req_i) begin
                        if (obi_we_i) begin
                            state_d   = ST_WR_RESP;
                            aw_done_d = 1'b0;
                            w_done_d  = 1'b0;
                        end else begin
                            state_d = ST_RD_ADDR;
                        end
                    end else begin
                        state_d = ST_IDLE;
                    end
                end
            end

            default: begin
                state_d = ST_IDLE;
            end
        endcase
    end

endmodule
