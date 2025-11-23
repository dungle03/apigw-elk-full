# Báo Cáo Hiệu Năng & Bảo Mật API Gateway

## 1. Tổng Quan Kịch Bản Test
Chúng tôi đã thực hiện chuỗi kiểm thử toàn diện từ cơ bản đến nâng cao để đánh giá hiệu quả của giải pháp API Gateway (Kong) kết hợp với ELK Stack.

Các kịch bản bao gồm:
1.  **Baseline:** Đo sức chịu đựng gốc của Backend (VPS).
2.  **Overhead:** Đo độ trễ khi đi qua Gateway.
3.  **Security:** Kiểm tra khả năng chặn tấn công (Rate Limiting).
4.  **Realistic (Mixed):** Giả lập môi trường thực tế (User thật + Attacker).
5.  **Resilience (Spike):** Kiểm tra khả năng phục hồi sau sốc tải.
6.  **Stability (Soak):** Kiểm tra độ ổn định khi chạy lâu dài.

---

## 2. Bảng Tổng Hợp Kết Quả Chi Tiết

| Nhóm Test | Kịch Bản Cụ Thể | Metric Quan Trọng | Kết Quả Đo Được | Đánh Giá / Ý Nghĩa |
| :--- | :--- | :--- | :--- | :--- |
| **A. Cơ Bản** | **1. Direct to VPS**<br>*(Không qua Gateway)* | Max Throughput | ............ req/s | Sức chịu đựng tối đa của phần cứng VPS. |
| | | Avg Latency | ............ ms | Độ trễ gốc của ứng dụng. |
| | **2. Gateway Overhead**<br>*(Qua Kong, tắt Limit)* | Max Throughput | ............ req/s | So với Direct: Giảm bao nhiêu %? (Tốt nếu < 10%) |
| | | Avg Latency | ............ ms | So với Direct: Tăng bao nhiêu ms? (Tốt nếu < 20ms) |
| **B. Bảo Mật** | **3. DDoS Attack**<br>*(Qua Kong, bật Limit)* | **Blocked Requests** | ............ % | **Kỳ vọng: > 99%** (Chặn đứng tấn công). |
| | | Latency (Blocked) | ............ ms | **Kỳ vọng: < 5ms** (Chặn ngay tại cửa, không tốn resource). |
| **C. Thực Tế** | **4. Mixed Traffic**<br>*(User thật vs Attacker)* | **Valid User Latency** | ............ ms | **Quan trọng nhất:** User thật có bị lag không? |
| | | Valid User Error | ............ % | **Kỳ vọng: 0%** (User thật không bị chặn nhầm). |
| | | Attacker Blocked | ............ % | Kỳ vọng: ~100% (Attacker bị chặn hết). |
| **D. Độ Bền** | **5. Spike Test**<br>*(Sốc tải 0->1000)* | Recovery Time | ............ s | Hệ thống mất bao lâu để ổn định lại sau đỉnh tải? |
| | | Max Error Rate | ............ % | Có bị sập (Crash) không? |
| | **6. Soak Test**<br>*(Chạy bền 30p)* | RAM Usage (Start) | ............ MB | |
| | | RAM Usage (End) | ............ MB | **Kỳ vọng: Không tăng** (Không Memory Leak). |

---

## 3. Kết Luận & Khuyến Nghị

### Đánh Giá Chung
*   **Hiệu năng:** Gateway làm tăng độ trễ trung bình khoảng `...ms`, nằm trong ngưỡng chấp nhận được.
*   **Bảo mật:** Cơ chế Rate Limiting hoạt động hiệu quả, chặn được `...%` các request tấn công thử nghiệm.
*   **Trải nghiệm người dùng:** Trong điều kiện bị tấn công giả lập, người dùng bình thường vẫn truy cập được với độ trễ `...ms`.

### Khuyến Nghị
*   Cần tinh chỉnh Rate Limit cho từng Route cụ thể hơn dựa trên hành vi người dùng thực tế.
*   Cân nhắc mở rộng (Scale up) VPS nếu lượng User thật vượt quá `...` concurrent users.
