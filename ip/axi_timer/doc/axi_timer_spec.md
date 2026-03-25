# AXI Timer 設計規格

## 1. 概述
32-bit 計時器，AXI4-Lite Slave 介面，支援比較匹配中斷及自動重載。

## 2. 暫存器映射
| 偏移 | 名稱 | 存取 | 說明 |
|------|------|------|------|
| 0x00 | CTRL | RW | [0] enable, [1] irq_en, [2] auto_reload |
| 0x04 | STATUS | R/W1C | [0] compare_match（寫 1 清除） |
| 0x08 | COUNT | R | 目前計數值 |
| 0x0C | COMPARE | RW | 比較匹配值 |

## 3. 功能描述
- 計數器每 clock 遞增 1（當 enable=1）
- 當 COUNT == COMPARE 且 COMPARE != 0 時觸發 match
- auto_reload=1：match 後計數器歸零重新開始
- auto_reload=0：match 後計數器停止

## 4. 中斷
- `irq` = `match_flag` AND `irq_en`
- 透過寫入 STATUS[0]=1 清除 match_flag (W1C)
