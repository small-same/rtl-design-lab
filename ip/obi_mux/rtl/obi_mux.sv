// OBI 2-to-1 Multiplexer / Arbiter
// Arbitrates between instruction and data OBI ports into a single OBI master.
// Data port has higher priority (fixed-priority arbiter).
`timescale 1ns/1ps

module obi_mux #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                      clk,
    input  logic                      rst_n,

    // OBI port 0: Instruction fetch (lower priority)
    input  logic                      instr_req_i,
    output logic                      instr_gnt_o,
    output logic                      instr_rvalid_o,
    input  logic [ADDR_WIDTH-1:0]     instr_addr_i,
    output logic [DATA_WIDTH-1:0]     instr_rdata_o,
    output logic                      instr_err_o,

    // OBI port 1: Data access (higher priority)
    input  logic                      data_req_i,
    output logic                      data_gnt_o,
    output logic                      data_rvalid_o,
    input  logic                      data_we_i,
    input  logic [DATA_WIDTH/8-1:0]   data_be_i,
    input  logic [ADDR_WIDTH-1:0]     data_addr_i,
    input  logic [DATA_WIDTH-1:0]     data_wdata_i,
    output logic [DATA_WIDTH-1:0]     data_rdata_o,
    output logic                      data_err_o,

    // Merged OBI master output
    output logic                      obi_req_o,
    input  logic                      obi_gnt_i,
    input  logic                      obi_rvalid_i,
    output logic                      obi_we_o,
    output logic [DATA_WIDTH/8-1:0]   obi_be_o,
    output logic [ADDR_WIDTH-1:0]     obi_addr_o,
    output logic [DATA_WIDTH-1:0]     obi_wdata_o,
    input  logic [DATA_WIDTH-1:0]     obi_rdata_i,
    input  logic                      obi_err_i
);

    // Track which port owns the outstanding transaction (response phase)
    // 0 = instr, 1 = data
    logic resp_sel_q;
    logic resp_pending_q;

    // Arbitration: data has priority, but only grant a new request when no
    // response is pending (simple in-order, one outstanding transaction)
    logic sel_data;
    logic sel_instr;
    logic can_accept;

    assign can_accept = ~resp_pending_q | obi_rvalid_i;
    assign sel_data   = data_req_i & can_accept;
    assign sel_instr  = instr_req_i & ~data_req_i & can_accept;

    // OBI master request
    assign obi_req_o   = sel_data | sel_instr;
    assign obi_we_o    = sel_data ? data_we_i    : 1'b0;
    assign obi_be_o    = sel_data ? data_be_i    : 4'hF;
    assign obi_addr_o  = sel_data ? data_addr_i  : instr_addr_i;
    assign obi_wdata_o = sel_data ? data_wdata_i : '0;

    // Grant back to ports
    assign data_gnt_o  = sel_data  & obi_gnt_i;
    assign instr_gnt_o = sel_instr & obi_gnt_i;

    // Response tracking
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            resp_pending_q <= 1'b0;
            resp_sel_q     <= 1'b0;
        end else begin
            if (obi_rvalid_i && !((sel_data | sel_instr) && obi_gnt_i)) begin
                // Response received, no new grant this cycle
                resp_pending_q <= 1'b0;
            end else if (!obi_rvalid_i && ((sel_data | sel_instr) && obi_gnt_i)) begin
                // New grant, no response this cycle
                resp_pending_q <= 1'b1;
                resp_sel_q     <= sel_data;
            end else if (obi_rvalid_i && ((sel_data | sel_instr) && obi_gnt_i)) begin
                // Response and new grant same cycle (back-to-back)
                resp_pending_q <= 1'b1;
                resp_sel_q     <= sel_data;
            end
            // else: no response, no grant — keep state
        end
    end

    // Route response to correct port
    assign instr_rvalid_o = obi_rvalid_i & ~resp_sel_q;
    assign data_rvalid_o  = obi_rvalid_i &  resp_sel_q;

    assign instr_rdata_o = obi_rdata_i;
    assign data_rdata_o  = obi_rdata_i;

    assign instr_err_o = obi_err_i & ~resp_sel_q;
    assign data_err_o  = obi_err_i &  resp_sel_q;

endmodule
