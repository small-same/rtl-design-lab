// Asynchronous FIFO with Gray-code pointer synchronization
// Suitable for CDC between two independent clock domains
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    // Write domain
    input  logic                    wr_clk,
    input  logic                    wr_rst_n,
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]  wr_data,
    output logic                    full,

    // Read domain
    input  logic                    rd_clk,
    input  logic                    rd_rst_n,
    input  logic                    rd_en,
    output logic [DATA_WIDTH-1:0]  rd_data,
    output logic                    empty
);

    // ---------------------------------------------------------------
    // Memory
    // ---------------------------------------------------------------
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // ---------------------------------------------------------------
    // Write-domain pointer (binary & gray)
    // ---------------------------------------------------------------
    logic [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_gray;
    logic [ADDR_WIDTH:0] wr_ptr_gray_next;

    assign wr_ptr_gray_next = (wr_ptr_bin + 1'b1) ^ ((wr_ptr_bin + 1'b1) >> 1);

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr_bin  <= wr_ptr_bin + 1'b1;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end

    // ---------------------------------------------------------------
    // Read-domain pointer (binary & gray)
    // ---------------------------------------------------------------
    logic [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_gray;
    logic [ADDR_WIDTH:0] rd_ptr_gray_next;

    assign rd_ptr_gray_next = (rd_ptr_bin + 1'b1) ^ ((rd_ptr_bin + 1'b1) >> 1);

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
        end else if (rd_en && !empty) begin
            rd_ptr_bin  <= rd_ptr_bin + 1'b1;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    // ---------------------------------------------------------------
    // Gray-code pointer synchronization
    // ---------------------------------------------------------------
    logic [ADDR_WIDTH:0] wr_ptr_gray_sync;
    logic [ADDR_WIDTH:0] rd_ptr_gray_sync;

    // Synchronize write pointer into read domain
    logic [ADDR_WIDTH:0] wr_gray_meta, wr_gray_sync;
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_gray_meta <= '0;
            wr_gray_sync <= '0;
        end else begin
            wr_gray_meta <= wr_ptr_gray;
            wr_gray_sync <= wr_gray_meta;
        end
    end
    assign wr_ptr_gray_sync = wr_gray_sync;

    // Synchronize read pointer into write domain
    logic [ADDR_WIDTH:0] rd_gray_meta, rd_gray_sync;
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_gray_meta <= '0;
            rd_gray_sync <= '0;
        end else begin
            rd_gray_meta <= rd_ptr_gray;
            rd_gray_sync <= rd_gray_meta;
        end
    end
    assign rd_ptr_gray_sync = rd_gray_sync;

    // ---------------------------------------------------------------
    // Full & Empty flags
    // ---------------------------------------------------------------
    assign full  = (wr_ptr_gray == {~rd_ptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1],
                                      rd_ptr_gray_sync[ADDR_WIDTH-2:0]});
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync);

endmodule
