# Hướng Dẫn Toàn Diện: Kiểm Thử Hiệu Năng & Bảo Mật API Gateway

Tài liệu này là hướng dẫn **duy nhất và đầy đủ nhất** để bạn thực hiện kiểm thử, từ các bước cấu hình cơ bản đến các kịch bản thực tế nâng cao, và cuối cùng là mẫu báo cáo kết quả.

---

## PHẦN 1: CHUẨN BỊ CẤU HÌNH (QUAN TRỌNG)

Để chạy được các kịch bản nâng cao (Mixed Traffic), bạn cần cấu hình Kong để phân loại luồng traffic:
1.  **Siết chặt** trang Login (`auth-service`) để chặn tấn công.
2.  **Nới lỏng** trang API (`user-service`) để đo hiệu năng User thật.

**Cách làm:**
Sửa file `kong/kong.yml`:
```yaml
services:
  - name: auth-service
    # ...
    plugins:
      - name: rate-limiting
        config:
          second: 5      # Chặn chặt (5 req/s)
          minute: 100
          policy: local

  - name: user-service
    # ...
    plugins:
      - name: rate-limiting
        config:
          minute: 10000  # Mở rộng (10,000 req/phút) cho User thật
          policy: local
```
Sau đó chạy lệnh update: `pwsh -File .\scripts\update-kong.ps1`

---

## PHẦN 2: CÁC KỊCH BẢN TEST (TỪ CƠ BẢN ĐẾN NÂNG CAO)

### 1. Baseline Test (Sức Chịu Đựng Gốc)
*Mục đích: Xem VPS chịu được bao nhiêu khi không có Gateway.*
*   **Target:** `http://<IP_VPS>:3000/api/me`
*   **JMeter:** 500 Users, Ramp-up 10s.
*   **Kỳ vọng:** Throughput cao nhất, Latency thấp nhất.

### 2. Gateway Overhead (Độ Trễ Gateway)
*Mục đích: Đo xem Gateway làm chậm hệ thống bao nhiêu.*
*   **Target:** `http://localhost:8000/api/me` (Qua Kong)
*   **JMeter:** 500 Users, Ramp-up 10s.
*   **Kỳ vọng:** Throughput giảm nhẹ (<10%), Latency tăng nhẹ (<20ms) so với Baseline.

### 3. Mixed Traffic (Giao Thông Hỗn Hợp - *Thực Tế Nhất*)
*Mục đích: Chứng minh Gateway bảo vệ User thật khi đang bị tấn công.*
*   **Cấu hình JMeter (2 Thread Group chạy song song):**
    *   **Group A (Valid Users):** 50 Users -> `GET /api/me` (Kèm Token). Target: 50 req/s.
    *   **Group B (Attackers):** 100 Users -> `POST /auth/login` (Sai pass). Max speed.
*   **Kỳ vọng:**
    *   **User thật:** Error 0%, Latency ổn định.
    *   **Attacker:** Error ~100% (429 Too Many Requests).

### 4. Spike Test (Sốc Tải)
*Mục đích: Kiểm tra khả năng phục hồi (Resilience).*
*   **JMeter:** Tăng từ 0 lên **1000 Users** trong **5 giây**.
*   **Kỳ vọng:** Hệ thống không sập (Crash). Sau khi hết đỉnh tải, Latency giảm ngay về mức bình thường.

### 5. Soak Test (Chạy Bền)
*Mục đích: Kiểm tra độ ổn định (Stability).*
*   **JMeter:** 200 Users chạy liên tục trong **30 phút**.
*   **Kỳ vọng:** RAM/CPU VPS không tăng dần theo thời gian (Không Memory Leak).

---

## PHẦN 3: BẢNG TỔNG HỢP KẾT QUẢ (DÙNG CHO BÁO CÁO)

Điền số liệu bạn đo được vào bảng này để hoàn thiện báo cáo cuối cùng.

| Nhóm Test | Kịch Bản | Metric Quan Trọng | Kết Quả Đo Được | Đánh Giá / Ý Nghĩa |
| :--- | :--- | :--- | :--- | :--- |
| **A. Cơ Bản** | **1. Direct to VPS** | Max Throughput | ............ req/s | Sức chịu đựng tối đa của phần cứng VPS. |
| | | Avg Latency | ............ ms | Độ trễ gốc của ứng dụng. |
| | **2. Gateway Overhead** | Max Throughput | ............ req/s | So với Direct: Giảm bao nhiêu %? |
| | | Avg Latency | ............ ms | So với Direct: Tăng bao nhiêu ms? |
| **B. Bảo Mật** | **3. Mixed Traffic**<br>*(User thật vs Attacker)* | **Valid User Latency** | ............ ms | **Quan trọng nhất:** User thật có bị lag không? |
| | | Valid User Error | ............ % | **Kỳ vọng: 0%** (User thật an toàn). |
| | | Attacker Blocked | ............ % | Kỳ vọng: ~100% (Attacker bị chặn hết). |
| **C. Độ Bền** | **4. Spike Test** | Recovery Time | ............ s | Thời gian ổn định lại sau sốc tải. |
| | **5. Soak Test** | Stability | ............ % | Độ lệch Latency giữa phút 1 và phút 30. |

---
**Kết Luận:**
Dựa trên số liệu trên, hệ thống API Gateway đã chứng minh khả năng bảo vệ Backend hiệu quả trước các cuộc tấn công DDoS giả lập, đồng thời duy trì hiệu năng ổn định cho người dùng thực tế.
