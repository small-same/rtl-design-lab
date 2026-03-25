// AXI DMA UVM Testbench - 範例檔案（含故意的 UVM 方法論問題）
`include "uvm_macros.svh"
import uvm_pkg::*;

// [UVM 問題] 缺少 `uvm_object_utils 註冊
class axi_dma_txn extends uvm_sequence_item;
    rand bit [31:0] src_addr;
    rand bit [31:0] dst_addr;
    rand bit [15:0] xfer_len;

    // 缺少 `uvm_object_utils(axi_dma_txn)
    // 缺少 field macros 或手動 do_copy/do_compare

    function new(string name = "axi_dma_txn");
        super.new(name);
    endfunction

    constraint valid_len {
        xfer_len inside {[1:256]};
    }
endclass

// Driver
class axi_dma_driver extends uvm_driver #(axi_dma_txn);
    `uvm_component_utils(axi_dma_driver)

    virtual axi_dma_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // [UVM 問題] 在 build_phase 中直接存取 interface，應使用 config_db
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 缺少: uvm_config_db#(virtual axi_dma_if)::get(this, "", "vif", vif)
    endfunction

    task run_phase(uvm_phase phase);
        axi_dma_txn txn;
        forever begin
            seq_item_port.get_next_item(txn);
            drive_txn(txn);
            seq_item_port.item_done();
        end
    endtask

    task drive_txn(axi_dma_txn txn);
        // [簡化] 驅動邏輯省略
        @(posedge vif.clk);
        vif.dma_start <= 1'b1;
        vif.src_addr  <= txn.src_addr;
        vif.dst_addr  <= txn.dst_addr;
        vif.xfer_len  <= txn.xfer_len;
        @(posedge vif.clk);
        vif.dma_start <= 1'b0;
    endtask
endclass

// Monitor — [UVM 問題] 缺少 analysis_port
class axi_dma_monitor extends uvm_monitor;
    `uvm_component_utils(axi_dma_monitor)

    virtual axi_dma_if vif;
    // 缺少: uvm_analysis_port #(axi_dma_txn) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // [UVM 問題] 缺少 build_phase 中的 analysis_port 建構
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 缺少: ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        // [簡化] 監控邏輯省略
        forever begin
            @(posedge vif.clk);
            if (vif.dma_done) begin
                `uvm_info("MON", "DMA transfer complete", UVM_MEDIUM)
                // 缺少: ap.write(txn) 將交易送至 scoreboard
            end
        end
    endtask
endclass

// Scoreboard — [Coverage 問題] 缺少 functional coverage
class axi_dma_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi_dma_scoreboard)

    // 缺少: uvm_analysis_imp #(axi_dma_txn, axi_dma_scoreboard) imp;
    // 缺少: covergroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // 缺少: write() function for analysis_imp
endclass

// Environment — [UVM 問題] connect_phase 中缺少 TLM 連接
class axi_dma_env extends uvm_env;
    `uvm_component_utils(axi_dma_env)

    axi_dma_driver  drv;
    axi_dma_monitor mon;
    axi_dma_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = axi_dma_driver::type_id::create("drv", this);
        mon = axi_dma_monitor::type_id::create("mon", this);
        sb  = axi_dma_scoreboard::type_id::create("sb", this);
    endfunction

    // [UVM 問題] connect_phase 為空，monitor 與 scoreboard 未連接
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // 缺少: mon.ap.connect(sb.imp);
    endfunction
endclass

// Interface
interface axi_dma_if(input logic clk, input logic rst);
    logic        dma_start;
    logic [31:0] src_addr;
    logic [31:0] dst_addr;
    logic [15:0] xfer_len;
    logic        dma_done;
endinterface
