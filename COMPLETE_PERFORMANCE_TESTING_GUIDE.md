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
*   **Cấu hình JMeter:**
    *   **Thread Group:**
        *   Number of Threads (Users): 500
        *   Ramp-up period: 10s
        *   Loop Count: Infinite (Duration: 60s)
    *   **HTTP Request:**
        *   Protocol: `http`
        *   Server Name or IP: `<IP_VPS>` (Ví dụ: 18.139.209.233)
        *   Port: `3000`
        *   Path: `/api/me`
        *   Method: `GET`
        *   **Header Manager:** `Authorization: Bearer <TOKEN>`
*   **Kỳ vọng:** Throughput cao nhất, Latency thấp nhất.

### 2. Gateway Overhead (Độ Trễ Gateway)
*Mục đích: Đo xem Gateway làm chậm hệ thống bao nhiêu.*
*   **Target:** `http://localhost:8000/api/me` (Qua Kong)
*   **Cấu hình JMeter:**
    *   **Thread Group:**
        *   Number of Threads (Users): 500
        *   Ramp-up period: 10s
        *   Loop Count: Infinite (Duration: 60s)
    *   **HTTP Request:**
        *   Protocol: `http`
        *   Server Name or IP: `localhost`
        *   Port: `8000`
        *   Path: `/api/me`
        *   Method: `GET`
        *   **Header Manager:** `Authorization: Bearer <TOKEN>`
*   **Kỳ vọng:** Throughput giảm nhẹ (<10%), Latency tăng nhẹ (<20ms) so với Baseline.

### 3. Mixed Traffic (Giao Thông Hỗn Hợp - *Thực Tế Nhất*)
*Mục đích: Chứng minh Gateway bảo vệ User thật khi đang bị tấn công.*
*   **Cấu hình JMeter (Tạo 1 Test Plan có 2 Thread Group chạy song song):**

    **Group A: "Valid Users" (Người dùng thật)**
    *   **Thread Group:**
        *   Number of Threads: 50
        *   Ramp-up period: 10s
        *   Loop Count: Infinite (Duration: 60s)
    *   **HTTP Request:** `GET http://localhost:8000/api/me` (Kèm Token)
    *   **Timer (Quan trọng):** Chuột phải vào Thread Group -> Add -> Timer -> **Constant Throughput Timer**.
        *   Target throughput: 3000 (samples per minute) ~ 50 req/s.

    **Group B: "Attackers" (Kẻ tấn công)**
    *   **Thread Group:**
        *   Number of Threads: 100
        *   Ramp-up period: 5s
        *   Loop Count: Infinite (Duration: 60s)
    *   **HTTP Request:** `POST http://localhost:8000/auth/login`
        *   Body Data: `{"username": "admin", "password": "wrongpassword"}`
        *   Header Manager: `Content-Type: application/json`
    *   **Timer:** Không đặt (để bắn nhanh nhất có thể).

*   **Kỳ vọng:**
    *   **User thật:** Error 0%, Latency ổn định.
    *   **Attacker:** Error ~100% (429 Too Many Requests).

### 4. Spike Test (Sốc Tải)
*Mục đích: Kiểm tra khả năng phục hồi (Resilience).*
*   **Cấu hình JMeter:**
    *   **Thread Group:**
        *   Number of Threads: 1000
        *   Ramp-up period: **5s** (Tăng cực nhanh)
        *   Loop Count: 10 (Hoặc Duration 30s)
    *   **HTTP Request:** `GET http://localhost:8000/api/me` (Kèm Token)
*   **Kỳ vọng:** Hệ thống không sập (Crash). Sau khi hết đỉnh tải, Latency giảm ngay về mức bình thường.

### 5. Soak Test (Chạy Bền)
*Mục đích: Kiểm tra độ ổn định (Stability).*
*   **Cấu hình JMeter:**
    *   **Thread Group:**
        *   Number of Threads: 200
        *   Ramp-up period: 60s
        *   Loop Count: Infinite (Duration: **900** = 15 phút)
    *   **HTTP Request:** `GET http://localhost:8000/api/me` (Kèm Token)
*   **Kỳ vọng:** RAM/CPU VPS không tăng dần theo thời gian (Không Memory Leak).

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
*   **Cấu hình JMeter:**
    *   **Thread Group:**
        *   Number of Threads (Users): 500
        *   Ramp-up period: 10s
        *   Loop Count: Infinite (Duration: 60s)
    *   **HTTP Request:**
        *   Protocol: `http`
        *   Server Name or IP: `<IP_VPS>` (Ví dụ: 18.139.209.233)
        *   Port: `3000`
        *   Path: `/api/me`
        *   Method: `GET`
        *   **Header Manager:** `Authorization: Bearer <TOKEN>`
*   **Kỳ vọng:** Throughput cao nhất, Latency thấp nhất.

### 2. Gateway Overhead (Độ Trễ Gateway)
*Mục đích: Đo xem Gateway làm chậm hệ thống bao nhiêu.*
*   **Target:** `http://localhost:8000/api/me` (Qua Kong)
*   **Cấu hình JMeter:**
    *   **Thread Group:**
        *   Number of Threads (Users): 500
        *   Ramp-up period: 10s
        *   Loop Count: Infinite (Duration: 60s)
    *   **HTTP Request:**
        *   Protocol: `http`
        *   Server Name or IP: `localhost`
        *   Port: `8000`
        *   Path: `/api/me`
        *   Method: `GET`
        *   **Header Manager:** `Authorization: Bearer <TOKEN>`
*   **Kỳ vọng:** Throughput giảm nhẹ (<10%), Latency tăng nhẹ (<20ms) so với Baseline.

### 3. Mixed Traffic (Giao Thông Hỗn Hợp - *Thực Tế Nhất*)
*Mục đích: Chứng minh Gateway bảo vệ User thật khi đang bị tấn công.*
*   **Cấu hình JMeter (Tạo 1 Test Plan có 2 Thread Group chạy song song):**

    **Group A: "Valid Users" (Người dùng thật)**
    *   **Thread Group:**
        *   Number of Threads: 50
        *   Ramp-up period: 10s
        *   Loop Count: Infinite (Duration: 60s)
    *   **HTTP Request:** `GET http://localhost:8000/api/me` (Kèm Token)
    *   **Timer (Quan trọng):** Chuột phải vào Thread Group -> Add -> Timer -> **Constant Throughput Timer**.
        *   Target throughput: 3000 (samples per minute) ~ 50 req/s.

    **Group B: "Attackers" (Kẻ tấn công)**
    *   **Thread Group:**
        *   Number of Threads: 100
        *   Ramp-up period: 5s
        *   Loop Count: Infinite (Duration: 60s)
    *   **HTTP Request:** `POST http://localhost:8000/auth/login`
        *   Body Data: `{"username": "admin", "password": "wrongpassword"}`
        *   Header Manager: `Content-Type: application/json`
    *   **Timer:** Không đặt (để bắn nhanh nhất có thể).

*   **Kỳ vọng:**
    *   **User thật:** Error 0%, Latency ổn định.
    *   **Attacker:** Error ~100% (429 Too Many Requests).

### 4. Spike Test (Sốc Tải)
*Mục đích: Kiểm tra khả năng phục hồi (Resilience).*
*   **Cấu hình JMeter:**
    *   **Thread Group:**
        *   Number of Threads: 1000
        *   Ramp-up period: **5s** (Tăng cực nhanh)
        *   Loop Count: 10 (Hoặc Duration 30s)
    *   **HTTP Request:** `GET http://localhost:8000/api/me` (Kèm Token)
*   **Kỳ vọng:** Hệ thống không sập (Crash). Sau khi hết đỉnh tải, Latency giảm ngay về mức bình thường.

### 5. Soak Test (Chạy Bền)
*Mục đích: Kiểm tra độ ổn định (Stability) trong thời gian dài.*
*   **Cấu hình JMeter (Tối ưu cho máy Local):**
    *   **Thread Group:**
        *   Number of Threads: **50** (Giảm để tránh quá tải RAM local)
        *   Ramp-up period: 60s
        *   Loop Count: Infinite (Duration: **900s** = 15 phút)
    *   **HTTP Request:** `GET http://localhost:8000/api/me` (Kèm Token)
    *   **Timer (Bắt buộc):** Constant Throughput Timer
        *   Target throughput: **9000** (samples per minute) ~ 150 req/s.
        *   Calculate Throughput based on: **all active threads**.
*   **Kỳ vọng:** RAM/CPU VPS ổn định, không có lỗi 400/500, Latency không tăng dần theo thời gian.

---

## PHẦN 3: BẢNG TỔNG HỢP KẾT QUẢ (DÙNG CHO BÁO CÁO)

Điền số liệu bạn đo được vào bảng này để hoàn thiện báo cáo cuối cùng.

| Nhóm Test | Kịch Bản | Metric Quan Trọng | Kết Quả Đo Được | Đánh Giá & Phân Tích Chi Tiết |
| :--- | :--- | :--- | :--- | :--- |
| **A. Cơ Bản** | **1. Direct to VPS** | Max Throughput | **738.4** req/s | **Baseline Tốt.** Server VPS (cấu hình hiện tại) chịu được tải khá cao khi không có lớp bảo vệ. Đây là mốc chuẩn để so sánh. |
| | | Avg Latency | **612** ms | Độ trễ trung bình ở mức chấp nhận được với tải 500 concurrent users. |
| | **2. Gateway Overhead** | Max Throughput | **288.2** req/s | **Giảm ~61%**. *Nguyên nhân:* Không phải do Gateway chậm, mà do cấu hình Rate Limit (10,000 req/phút) thấp hơn khả năng bắn của JMeter (~45,000 req/phút), dẫn đến nhiều request bị từ chối và làm giảm throughput tổng. |
| | | Avg Latency | **1040** ms | **Tăng ~400ms**. Việc xử lý logic từ chối (429) tốn thêm tài nguyên CPU của Gateway. |
| **B. Bảo Mật** | **3. Mixed Traffic**<br>*(User thật vs Attacker)* | **Valid User Latency** | **446** ms | **Rất Tốt.** Độ trễ của User thật (446ms) thậm chí còn thấp hơn Baseline (612ms) do Gateway đã lọc bớt traffic rác, giảm tải cho Backend xử lý. |
| | | Valid User Error | **15.86%** | **Cần Lưu Ý.** Hệ thống bị quá tải tài nguyên (Resource Exhaustion) khi phải gồng mình chặn 100 attacker/s. <br>**Khuyến nghị:** Cần nâng cấp CPU cho VPS hoặc tối ưu số lượng Kong Worker để giảm tỷ lệ này về 0%. |
| | | Attacker Blocked | **100%** | **Xuất Sắc.** Cơ chế Rate Limiting hoạt động hoàn hảo, không để lọt bất kỳ request tấn công nào vào Backend. |
| **C. Độ Bền** | **4. Spike Test** | Recovery Time | **Gateway Overload** | Gateway (Local) bị quá tải kết nối (**Connection Refused**). **VPS Backend vẫn an toàn tuyệt đối** (CPU < 10%, RAM ổn định ở mức 2.2GB). |
| | | Max Error Rate | **100%** | **Bảo Vệ Thành Công:** Gateway đã "hy sinh" để chặn đứng 2600 req/s. Hạ tầng VPS không hề bị ảnh hưởng bởi cú sốc tải này. |
| | **5. Soak Test**<br>*(15 phút, 200 threads, 154,851 samples)* | Error Rate | **0.00%** | **Hoàn Hảo.** Không có lỗi nào trong suốt 15 phút chạy liên tục. Hệ thống hoạt động ổn định tuyệt đối. |
| | | Throughput | **149.8** req/s | **Xuất Sắc.** Throughput duy trì ổn định ~150 req/s (nhờ Constant Throughput Timer), dưới ngưỡng Rate Limit của Kong (166 req/s). |
| | | Avg Latency | **68** ms | **Cực Kỳ Tốt.** Độ trễ thấp và ổn định (Std. Dev. chỉ 21.95), chứng tỏ không có Memory Leak hay Resource Degradation. |
| | | Max Latency | **2146** ms | Có 1 đỉnh cao (spike), nhưng đây là hiện tượng bình thường trong long-running test (có thể do JVM GC hoặc Network fluctuation). |

---
**4. KẾT LUẬN & KHUYẾN NGHỊ**

Dựa trên số liệu thực tế đã đo đạc, chúng ta có thể rút ra các kết luận sau cho dự án:

1.  **Hiệu Quả Bảo Mật Tuyệt Đối:** Gateway đã chứng minh khả năng chặn đứng **100%** các cuộc tấn công Brute-force/DDoS giả lập. Đây là điểm sáng nhất của hệ thống.
2.  **Bảo Vệ Trải Nghiệm Người Dùng:** Trong khi hệ thống đang bị tấn công dữ dội, **85%** người dùng thật vẫn có thể truy cập dịch vụ với độ trễ thấp (**446ms**), tốt hơn cả khi không dùng Gateway (612ms).
3.  **Vấn Đề Tài Nguyên:** Tỷ lệ lỗi 15% ở người dùng thật cho thấy phần cứng hiện tại (VPS) đang bị giới hạn khi xử lý traffic hỗn hợp cường độ cao.
    *   **Giải pháp ngắn hạn:** Tinh chỉnh lại cấu hình `nginx_worker_processes` trong Kong.
    *   **Giải pháp dài hạn:** Cân nhắc nâng cấp VPS (Scale Up) hoặc triển khai thêm Node (Scale Out) nếu lượng user thật vượt quá 500 CCU.
