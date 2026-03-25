# AXI UART Lite 設計規格

## 1. 概述
精簡 UART 控制器，AXI4-Lite Slave 介面，內建 TX/RX FIFO，支援 Loopback 模式用於模擬驗證。

## 2. 暫存器映射
| 偏移 | 名稱 | 存取 | 說明 |
|------|------|------|------|
| 0x00 | TX_DATA | W | 寫入待傳送位元組 |
| 0x04 | RX_DATA | R | 讀取接收位元組（自動彈出 FIFO） |
| 0x08 | STATUS | R | [0] tx_full, [1] rx_empty, [2] rx_valid |
| 0x0C | CONTROL | RW | [0] irq_en（RX 資料可用中斷） |

## 3. 設計參數
| 參數 | 預設值 | 說明 |
|------|--------|------|
| FIFO_DEPTH | 16 | TX/RX FIFO 深度 |

## 4. Loopback 模式
模擬時 TX FIFO 資料直接轉入 RX FIFO，不經由實際 UART 線路。

## 5. 中斷
- `irq` = `irq_en` AND `!rx_empty`
- 當 CONTROL[0] 啟用且 RX FIFO 非空時觸發
