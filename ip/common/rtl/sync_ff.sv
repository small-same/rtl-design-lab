// 2-Stage Flip-Flop Synchronizer
// Used for single-bit CDC (Clock Domain Crossing) synchronization
module sync_ff #(
    parameter STAGES    = 2,
    parameter RST_VALUE = 1'b0
)(
    input  logic clk,
    input  logic rst_n,
    input  logic data_i,
    output logic data_o
);

    logic [STAGES-1:0] sync_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_q <= {STAGES{RST_VALUE}};
        end else begin
            sync_q <= {sync_q[STAGES-2:0], data_i};
        end
    end

    assign data_o = sync_q[STAGES-1];

endmodule
