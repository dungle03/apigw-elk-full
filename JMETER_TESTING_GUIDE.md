# Hướng Dẫn Kiểm Thử Hiệu Năng Với JMeter

Tài liệu này hướng dẫn chi tiết từng bước cách sử dụng **Apache JMeter** để đo lường hiệu năng và kiểm chứng khả năng bảo vệ của hệ thống API Gateway.

---

## 1. Chuẩn Bị Môi Trường

### 1.1. Cài đặt JMeter
1.  **Yêu cầu:** Máy tính đã cài đặt Java (JDK 8 trở lên).
2.  **Tải về:** Truy cập [jmeter.apache.org](https://jmeter.apache.org/download_jmeter.cgi) và tải file `.zip` (Binaries).
3.  **Cài đặt:** Giải nén file `.zip`.
4.  **Chạy:**
    -   Windows: Chạy file `bin/jmeter.bat`.
    -   Mac/Linux: Chạy file `bin/jmeter`.

### 1.2. Chuẩn bị Dữ Liệu Test
Bạn cần một **Access Token** hợp lệ để test các API được bảo vệ.
-   Dùng Postman gọi API Login (`POST http://localhost:8000/auth/login`) để lấy `access_token`.
-   Copy token này để dùng cho các bước sau.

---

## 2. Tạo Test Plan Cơ Bản

### Bước 1: Tạo Thread Group (Giả lập người dùng)
1.  Chuột phải vào **Test Plan** -> **Add** -> **Threads (Users)** -> **Thread Group**.
2.  Cấu hình:
    -   **Name:** `Normal Load Test`
    -   **Number of Threads (users):** `50` (50 người dùng cùng lúc).
    -   **Ramp-up period (seconds):** `10` (Tăng dần user trong 10s).
    -   **Loop Count:** Chọn **Infinite** (Vô hạn) hoặc nhập `100`.
    -   *Mẹo:* Nếu chọn Infinite, hãy đặt **Duration** (trong phần "Specify Thread lifetime") là `60` giây để test chạy trong 1 phút rồi dừng.

### Bước 2: Cấu hình HTTP Request Defaults
Giúp không phải nhập lại IP/Port nhiều lần.
1.  Chuột phải vào **Thread Group** -> **Add** -> **Config Element** -> **HTTP Request Defaults**.
2.  Cấu hình:
    -   **Protocol:** `http`
    -   **Server Name or IP:** `localhost` (nếu test qua Kong) hoặc IP VPS (nếu test trực tiếp).
    -   **Port Number:** `8000` (Kong) hoặc `3000` (Direct).
    -   **Content-Encoding:** `UTF-8`

### Bước 3: Thêm HTTP Header Manager (Để gắn Token)
1.  Chuột phải vào **Thread Group** -> **Add** -> **Config Element** -> **HTTP Header Manager**.
2.  Nhấn **Add** ở dưới cùng:
    -   **Name:** `Authorization`
    -   **Value:** `Bearer <Dán_Token_Của_Bạn_Vào_Đây>`

---

## 3. Các Kịch Bản Test (Scenarios)

### Kịch bản 1: Test Hiệu Năng Qua Gateway (Happy Case)
Mục tiêu: Đo khả năng chịu tải bình thường của hệ thống.

1.  **Thêm HTTP Request:**
    -   Chuột phải **Thread Group** -> **Add** -> **Sampler** -> **HTTP Request**.
    -   **Name:** `GET /api/me (Via Kong)`
    -   **Method:** `GET`
    -   **Path:** `/api/me` (hoặc API nào bạn muốn test).
2.  **Thêm Listener (Xem kết quả):**
    -   Chuột phải **Thread Group** -> **Add** -> **Listener** -> **View Results Tree** (Xem chi tiết từng request).
    -   Chuột phải **Thread Group** -> **Add** -> **Listener** -> **Summary Report** (Xem thống kê tổng quan).
3.  **Chạy Test:** Nhấn nút **Start** (Mũi tên xanh lá).

**Cách đọc Summary Report:**
-   **# Samples:** Tổng số request đã gửi.
-   **Average:** Thời gian phản hồi trung bình (ms). Thấp là tốt.
-   **Min/Max:** Thời gian nhanh nhất/chậm nhất.
-   **Error %:** Tỷ lệ lỗi. Phải là **0%** trong điều kiện bình thường.
-   **Throughput:** Số request xử lý được mỗi giây. Càng cao càng tốt.

---

### Kịch bản 2: Stress Test & Rate Limiting (Attack Case)
Mục tiêu: Kiểm chứng Kong chặn tấn công như thế nào.

1.  **Tạo Thread Group Mới:** Tên là `DDOS Attack`.
2.  **Cấu hình "Khủng":**
    -   **Number of Threads:** `200` (hoặc cao hơn).
    -   **Ramp-up period:** `1` (Tấn công dồn dập ngay lập tức).
    -   **Loop Count:** `Infinite`.
3.  **Thêm HTTP Request:** Gọi vào API Login (thường bị giới hạn chặt hơn).
    -   **Path:** `/auth/login`
    -   **Method:** `POST`
    -   **Body Data:**
        ```json
        {
          "username": "admin",
          "password": "wrongpassword"
        }
        ```
    -   *(Nhớ thêm HTTP Header Manager: `Content-Type: application/json`)*
4.  **Chạy và Quan Sát:**
    -   Trong **View Results Tree**, bạn sẽ thấy rất nhiều request màu đỏ.
    -   Bấm vào request đỏ, chọn tab **Response data**, bạn sẽ thấy:
        -   **Response code:** `429`
        -   **Response message:** `Too Many Requests`
        -   **Body:** `{"message":"API rate limit exceeded"}`

---

## 4. So Sánh: Có Gateway vs Không Có Gateway

Để làm nổi bật giá trị của dự án, hãy thực hiện bài test so sánh này và chụp ảnh màn hình báo cáo.

| Tiêu chí | Test Trực Tiếp (Direct to VPS:3000) | Test Qua Gateway (Localhost:8000) |
| :--- | :--- | :--- |
| **Cấu hình** | Thread: 500, Ramp-up: 5s | Thread: 500, Ramp-up: 5s |
| **Kết quả** | Server VPS có thể bị treo, CPU tăng vọt 100%. Request bắt đầu timeout hàng loạt. | Kong trả về `429` rất nhanh. Server VPS (Backend) vẫn "bình chân như vại", CPU thấp. |
| **Kết luận** | Backend dễ bị tổn thương. | Gateway bảo vệ Backend an toàn tuyệt đối. |

---

## 5. Mẹo "Ăn Điểm" Khi Demo
1.  **Mở song song 2 cửa sổ:**
    -   Một bên là **JMeter** đang chạy Stress Test (đỏ rực lỗi 429).
    -   Một bên là **Kibana Dashboard** (Discover), set chế độ **Auto-refresh (5 seconds)**.
2.  **Chỉ vào màn hình:** "Các bạn thấy đấy, ngay khi JMeter bắn request, Kibana lập tức hiển thị log 429. Chúng ta biết ngay ai đang tấn công và IP nào."

Chúc bạn demo thành công!
