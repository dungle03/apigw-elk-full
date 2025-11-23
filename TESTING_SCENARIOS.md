# Hướng Dẫn Chạy Kịch Bản Test Để Lấy Số Liệu

Với code hiện tại, bạn có thể thực hiện **3 kịch bản** sau để lấy đủ số liệu cho báo cáo.

> **Lưu ý quan trọng:** Để test hiệu năng (Throughput) qua Gateway, bạn cần **tạm thời tăng giới hạn Rate Limit** lên, nếu không sẽ chỉ toàn nhận lỗi 429 (như bạn vừa thấy).

---

## Kịch Bản 1: Đo Baseline (Truy cập Trực Tiếp VPS)
*Mục đích: Xem server VPS chịu được tối đa bao nhiêu tải khi không có bảo vệ.*

1.  **Cấu hình JMeter:**
    -   **Protocol:** `http`
    -   **Server:** `<IP_VPS_CỦA_BẠN>` (Ví dụ: `18.139.209.233`)
    -   **Port:** `3000`
    -   **Path:** `/api/me`
    -   **Users:** 500 (Ramp-up 10s).
2.  **Thực hiện:** Chạy test trong 60s.
3.  **Ghi lại số liệu:**
    -   **Throughput:** (Ví dụ: 1500/sec)
    -   **Avg Latency:** (Ví dụ: 50ms)
    -   **Error %:** (Nếu server quá tải, lỗi sẽ bắt đầu xuất hiện).

---

## Kịch Bản 2: Đo Max Throughput (Qua Gateway - Tắt Bảo Vệ)
*Mục đích: Chứng minh Gateway không làm chậm hệ thống đáng kể (Low Overhead).*

1.  **Bước chuẩn bị (Quan trọng):**
    -   Mở file `kong/kong.yml`.
    -   Tìm đến phần `rate-limiting` của `user-service`.
    -   Sửa `minute: 100` thành **`minute: 100000`** (Tăng cực lớn để không bị chặn).
    -   Chạy script để apply config mới:
        ```powershell
        # Windows
        pwsh -File .\scripts\update-kong.ps1
        ```
2.  **Cấu hình JMeter:**
    -   **Server:** `localhost`
    -   **Port:** `8000`
    -   **Path:** `/api/me`
    -   **Users:** 500 (Giống kịch bản 1).
3.  **Thực hiện:** Chạy test.
4.  **Ghi lại số liệu:**
    -   **Throughput:** (Sẽ thấp hơn Kịch bản 1 một chút, ví dụ 1300/sec -> Chấp nhận được).
    -   **Avg Latency:** (Sẽ cao hơn Kịch bản 1 khoảng 10-20ms -> Overhead của Gateway).
    -   **Error %:** Phải là 0%.

---

## Kịch Bản 3: Đo Hiệu Quả Bảo Mật (Qua Gateway - Bật Bảo Vệ)
*Mục đích: Chứng minh Gateway chặn tấn công DDoS.*

1.  **Bước chuẩn bị:**
    -   Sửa lại `kong/kong.yml` về như cũ: **`minute: 100`**.
    -   Chạy lại script `update-kong.ps1` để apply.
2.  **Cấu hình JMeter:**
    -   Giữ nguyên cấu hình (500 users).
3.  **Thực hiện:** Chạy test.
4.  **Ghi lại số liệu:**
    -   **Error %:** Sẽ rất cao (gần 100%).
    -   **Response Code:** Kiểm tra xem có phải toàn bộ là `429` không.
    -   **Kết luận:** Hệ thống đã chặn thành công 99% request tấn công.

---

## Bảng Tổng Hợp Kết Quả (Mẫu)

Sau khi chạy xong 3 kịch bản, bạn điền số liệu vào bảng này để báo cáo:

| Tiêu chí | Kịch bản 1 (Direct) | Kịch bản 2 (Gateway Max Speed) | Kịch bản 3 (Gateway Security) |
| :--- | :--- | :--- | :--- |
| **Mục đích** | Đo sức chịu đựng gốc của Server | Đo độ trễ (Overhead) của Gateway | Đo khả năng chặn tấn công |
| **Cấu hình Rate Limit** | N/A | 100,000 req/phút (Mở toang) | 100 req/phút (Siết chặt) |
| **Throughput** | 1500/sec | 1350/sec | ~1.6/sec (Chỉ cho phép 100/phút) |
| **Avg Latency** | 50ms | 65ms | 2ms (Trả lỗi ngay lập tức) |
| **Error Rate** | 0% (hoặc timeout nếu quá tải) | 0% | **~99% (Lỗi 429)** |
