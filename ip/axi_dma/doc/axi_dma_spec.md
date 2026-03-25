# AXI DMA Controller 設計規格

## 1. 概述
AXI DMA Controller 提供記憶體對記憶體的 DMA 傳輸功能，支援 AXI4 介面。

## 2. 設計參數
| 參數 | 預設值 | 說明 |
|------|--------|------|
| DATA_WIDTH | 32 | 資料匯流排寬度（支援 32/64/128） |
| ADDR_WIDTH | 32 | 位址匯流排寬度 |
| MAX_BURST_LEN | 256 | 最大 burst 長度 |
| FIFO_DEPTH | 16 | 內部 FIFO 深度 |

## 3. 介面信號
### 3.1 AXI Write Channel
- `awaddr` [ADDR_WIDTH-1:0] — 寫入位址
- `awlen` [7:0] — Burst 長度（AXI4 規範：實際長度 = awlen + 1）
- `awvalid` — 位址有效
- `awready` — Slave 就緒
- `wdata` [DATA_WIDTH-1:0] — 寫入資料
- `wlast` — 最後一筆資料
- `wvalid` — 資料有效
- `wready` — Slave 就緒
- `bresp` [1:0] — 寫入回應
- `bvalid` — 回應有效
- `bready` — Master 就緒

### 3.2 控制信號
- `dma_start` — 啟動 DMA 傳輸
- `src_addr` [ADDR_WIDTH-1:0] — 來源位址
- `dst_addr` [ADDR_WIDTH-1:0] — 目的位址
- `xfer_len` [15:0] — 傳輸長度（bytes）
- `dma_done` — 傳輸完成

## 4. 命名規範
- 模組名稱：小寫底線分隔（如 `axi_dma_core`）
- 參數：全大寫底線分隔（如 `DATA_WIDTH`）
- 低電位有效信號：後綴 `_n`（如 `rst_n`）
- 暫存器輸出/輸入：後綴 `_q` / `_d`
- CDC 信號：包含 `_cdc_` 或 `_sync_`

## 5. Reset 策略
- 使用非同步 reset、同步釋放（async assert, sync deassert）
- Reset 信號統一使用低電位有效（`rst_n`）
