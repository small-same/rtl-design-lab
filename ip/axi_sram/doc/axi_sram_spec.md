# AXI SRAM 設計規格

## 1. 概述
AXI4-Lite SRAM Slave，提供單埠 4KB 記憶體存取，支援 byte-strobe 寫入及 `$readmemh` 初始化。

## 2. 設計參數
| 參數 | 預設值 | 說明 |
|------|--------|------|
| ADDR_WIDTH | 32 | 位址匯流排寬度 |
| DATA_WIDTH | 32 | 資料匯流排寬度 |
| MEM_DEPTH | 1024 | 記憶體深度（words），1024×32 = 4KB |
| MEM_INIT_FILE | "" | 初始化檔案路徑（hex 格式），空字串表示不初始化 |

## 3. 介面信號
標準 AXI4-Lite Slave 介面（AW, W, B, AR, R 五通道）。

## 4. 功能描述
- 單週期讀取回應
- 寫入支援 `s_wstrb` byte-strobe
- 當 `MEM_INIT_FILE` 非空時，使用 `$readmemh` 載入初始內容
- 所有回應皆為 OKAY (bresp/rresp = 2'b00)

## 5. 記憶體映射
- 基底位址：由 SoC 互連決定（預設 0x0000_0000）
- 大小：4KB（0x000 ~ 0xFFF）
- 字元組對齊：4-byte aligned

## 6. Reset 策略
- 非同步 assert、同步 deassert、active-low（rst_n）
- Reset 清除所有控制暫存器，不清除記憶體內容
