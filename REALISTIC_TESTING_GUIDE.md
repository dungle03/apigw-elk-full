# Hướng Dẫn Chi Tiết: Kịch Bản Test Thực Tế & Cấu Hình

Tài liệu này hướng dẫn từng bước để bạn thực hiện 3 kịch bản test nâng cao.
**Mục tiêu:** Lấy số liệu cụ thể để chứng minh hệ thống vừa bảo mật tốt (chặn tấn công), vừa đảm bảo hiệu năng cho người dùng thật.

---

## 1. Chuẩn Bị Cấu Hình (BẮT BUỘC)

Để chạy được kịch bản **"Giao Thông Hỗn Hợp" (Mixed Traffic)**, ta cần cấu hình Kong để:
-   **Chặn** kẻ tấn công vào trang Login (`/auth/login`).
-   **Mở rộng** đường cho người dùng thật gọi API (`/api/me`).

### Bước 1: Sửa file `kong/kong.yml`
Bạn hãy sửa phần `rate-limiting` của 2 service như sau:

**a. Service `auth-service` (Nơi bị tấn công):**
*Giữ nguyên giới hạn thấp để chặn Brute-force.*
```yaml
  - name: auth-service
    # ...
    plugins:
      - name: rate-limiting
        config:
          second: 5      # Chỉ cho phép 5 req/s (Rất chặt)
          minute: 100
          policy: local
```

**b. Service `user-service` (Nơi người dùng thật sử dụng):**
*Tăng giới hạn lên cao để người dùng không bị chặn oan.*
```yaml
  - name: user-service
    # ...
    plugins:
      - name: rate-limiting
        config:
          minute: 10000  # Tăng lên 10,000 req/phút (Thoải mái cho user thật)
          policy: local
```

### Bước 2: Cập nhật Kong
Chạy lệnh sau để áp dụng cấu hình mới:
```powershell
# Windows
pwsh -File .\scripts\update-kong.ps1
```

---

## 2. Chi Tiết Từng Kịch Bản Test

### Kịch Bản 1: Mixed Traffic (Quan Trọng Nhất)
*Mô tả: 50 người dùng thật đang lướt web, trong khi 100 bot đang tấn công trang login.*

**Cấu hình JMeter (Tạo 1 Test Plan có 2 Thread Group chạy song song):**

*   **Thread Group A: "Valid Users"**
    *   **Number of Threads:** 50
    *   **Ramp-up period:** 10s
    *   **Loop Count:** Infinite (Chọn "Specify Thread lifetime" -> Duration: 60s)
    *   **HTTP Request:** `GET http://localhost:8000/api/me` (Kèm Header `Authorization: Bearer <TOKEN_THAT>`)
    *   **Timer:** Thêm `Constant Throughput Timer` -> Target throughput: 3000 (samples per minute) ~ 50 req/s.

*   **Thread Group B: "Attackers"**
    *   **Number of Threads:** 100
    *   **Ramp-up period:** 5s
    *   **Loop Count:** Infinite (Duration: 60s)
    *   **HTTP Request:** `POST http://localhost:8000/auth/login` (Body: `{"username": "admin", "password": "wrongpassword"}`)
    *   **Timer:** Không đặt (để bắn nhanh nhất có thể).

**Kết Quả Kỳ Vọng (Ghi vào báo cáo):**
-   **Valid Users:** Error 0%, Latency thấp (~50ms). -> *Hệ thống vẫn phục vụ tốt.*
-   **Attackers:** Error ~100% (Lỗi 429), Latency cực thấp (2ms). -> *Hệ thống chặn tốt.*

---

### Kịch Bản 2: Spike Test (Sốc Tải)
*Mô tả: Lượng truy cập tăng đột biến từ 0 lên 1000 trong 5 giây (Flash Sale).*

**Cấu hình JMeter:**
*   **Thread Group:**
    *   **Number of Threads:** 1000
    *   **Ramp-up period:** 5s (Rất gắt)
    *   **Loop Count:** 10 (Hoặc Duration 30s)
    *   **HTTP Request:** `GET http://localhost:8000/api/me`

**Kết Quả Kỳ Vọng:**
-   Quan sát biểu đồ **Response Time**: Sẽ tăng vọt lúc giây thứ 5.
-   **Quan trọng:** Sau khi hết đỉnh tải, Latency có giảm ngay về mức bình thường không? (Nếu có -> Hệ thống có khả năng phục hồi tốt).

---

### Kịch Bản 3: Soak Test (Chạy Bền)
*Mô tả: Chạy tải ổn định trong thời gian dài để tìm lỗi rò rỉ bộ nhớ.*

**Cấu hình JMeter:**
*   **Thread Group:**
    *   **Number of Threads:** 200
    *   **Ramp-up period:** 60s
    *   **Loop Count:** Infinite (Duration: 1800s = 30 phút)
    *   **HTTP Request:** `GET http://localhost:8000/api/me`

**Kết Quả Kỳ Vọng:**
-   So sánh Latency ở phút thứ 1 và phút thứ 30. Nếu ngang nhau -> Ổn định.
-   Kiểm tra RAM của VPS (lệnh `htop` hoặc `docker stats`). Nếu RAM không tăng dần theo thời gian -> Không bị Memory Leak.

---

## 3. Bảng Tổng Hợp Kết Quả (Mẫu Báo Cáo)

Sau khi chạy xong, bạn điền số liệu vào bảng này:

| Kịch Bản | Metric | Kết Quả Đo Được | Đánh Giá |
| :--- | :--- | :--- | :--- |
| **1. Mixed Traffic** | **Valid User Latency** | ...... ms | (Tốt nếu < 100ms) |
| | **Valid User Error %** | ...... % | (Bắt buộc phải là 0%) |
| | **Attacker Blocked %** | ...... % | (Tốt nếu > 99%) |
| **2. Spike Test** | **Max Latency** | ...... ms | (Lúc đỉnh tải) |
| | **Recovery Time** | ...... s | (Thời gian để ổn định lại) |
| **3. Soak Test** | **Stability** | ...... % | (Độ lệch Latency đầu/cuối) |
