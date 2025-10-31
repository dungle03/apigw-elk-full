# API Gateway Security Service

Một dự án mẫu trình diễn kiến trúc bảo mật API hiện đại, sử dụng Kong Gateway, Keycloak và ELK Stack để tạo ra một lớp bảo vệ trung tâm, chống lại các mối đe dọa phổ biến và cung cấp khả năng giám sát toàn diện.

---

## 1. Bối Cảnh & Vấn Đề

Ngày nay, API là xương sống của hầu hết các ứng dụng hiện đại. Tuy nhiên, chúng cũng là mục tiêu tấn công hàng đầu. Dự án này được xây dựng để giải quyết các vấn đề thực tế:
- **Tấn công Brute-Force:** Theo Kaspersky, Việt Nam đứng đầu Đông Nam Á về tấn công "vét cạn" (brute-force) năm 2024.
- **Lỗ hổng bảo mật:** Các backend service thường thiếu các lớp bảo vệ chuyên biệt, dễ bị tấn công bởi dữ liệu không hợp lệ.
- **Thiếu khả năng giám sát:** Khi sự cố xảy ra, việc điều tra và truy vết rất khó khăn do log phân tán.

---

## 2. Kiến Trúc Giải Pháp (Mô Hình Hybrid)

Để tối ưu hiệu năng và mô phỏng môi trường triển khai thực tế, dự án được triển khai theo mô hình **Hybrid**:
- **Máy chủ VPS (Từ xa):** Chạy các dịch vụ "nặng" như Keycloak, User Service và bộ ELK Stack.
- **Máy Local (Máy thật):** Chỉ chạy thành phần nhẹ là Kong API Gateway, đóng vai trò là cổng vào duy nhất.

```mermaid
flowchart LR
    subgraph "Máy Local (Của Bạn)"
        A[User / Postman / k6]
        B[Kong API Gateway]
    end

    subgraph "Máy chủ VPS (Từ xa)"
        subgraph "Security & Services"
            C[Keycloak (Identity Provider)]
            D[NestJS User Service]
        end
        subgraph "Observability Stack"
            E[Logstash]
            F[Elasticsearch]
            G[Kibana Dashboard]
        end
    end

    %% Connections
    A --> B
    B -- "Gửi request qua Internet" --> D
    B -- "Xác thực token" --> C
    B -- "Gửi log" --> E
    E --> F
    F --> G
```

---

## 3. Các Lớp Bảo Mật Chính

- **🛡️ Lớp 1: Gateway (Kong)**
  - **Xác thực JWT:** Kiểm tra chữ ký và thời hạn của token do Keycloak cấp.
  - **Chống Brute-Force:** Áp dụng Rate Limiting (giới hạn 5 request/giây) trên endpoint đăng nhập.
  - **Validation Payload:** Dùng script Lua để kiểm tra cấu trúc và định dạng dữ liệu đầu vào.
- **📈 Lớp 2: Giám Sát (ELK Stack)**
  - **Logging Tập Trung:** Mọi request đi qua Kong đều được ghi log và đẩy về Logstash.
  - **Làm giàu Dữ liệu:** Logstash xử lý, trích xuất thông tin quan trọng (status, IP, latency) và thêm dữ liệu vị trí địa lý (GeoIP).
  - **Trực quan hóa:** Kibana cung cấp giao diện để tìm kiếm, lọc và tạo biểu đồ từ log, giúp phát hiện tấn công trong thời gian thực.

---

## 4. Hướng Dẫn Cài Đặt và Vận Hành

### Bước 1: Cài Đặt Trên Máy Chủ VPS
Đây là nơi chạy các dịch vụ backend.
> 📖 **Lưu ý:** Để có hướng dẫn chi tiết từng lệnh, vui lòng xem file **[SETUP_REMOTE_INFRA.md](./SETUP_REMOTE_INFRA.md)**.

1.  **Chuẩn bị VPS:** Chuẩn bị một máy chủ Ubuntu và mở các cổng `3000`, `8080`, `8081`, `9200`, `5601`.
2.  **Cài Docker & Tải Mã Nguồn:** Cài đặt Docker, Docker Compose và clone repository này về VPS.
3.  **Khởi chạy Dịch Vụ Nền:** Chạy lệnh sau trên VPS để khởi động tất cả các service **TRỪ KONG**:
    ```bash
    docker compose up -d usersvc keycloak keycloak-db logstash elasticsearch kibana
    ```
4.  **Kiểm Tra:** Dùng `docker compose ps` để đảm bảo tất cả các service đã `healthy`. Ghi lại địa chỉ **IP Public của VPS**.

### Bước 2: Cài Đặt Trên Máy Local
Đây là nơi chỉ chạy Kong API Gateway.

1.  **Cấu hình Kong:** Mở file `kong/kong.yml`. Tìm và thay thế tất cả các địa chỉ IP cũ bằng **IP Public của VPS** của bạn.
2.  **Khởi chạy Kong:** Sử dụng file `docker-compose.kong-only.yml`:
    ```bash
    docker compose -f docker-compose.kong-only.yml up -d --build
    ```

### Bước 3: Kiểm Thử Với Postman
> 📖 **Lưu ý:** Để có hướng dẫn chi tiết từng bước trên Postman, vui lòng xem file **[POSTMAN_TESTING_GUIDE.md](./POSTMAN_TESTING_GUIDE.md)**.

1.  **Đăng nhập thành công:** Gửi request `POST` đến `http://localhost:8000/auth/login` với `username` và `password` để nhận `access_token`.
2.  **Truy cập API được bảo vệ:** Gửi request `GET` đến `http://localhost:8000/api/me` với `Authorization: Bearer <token>` để lấy thông tin người dùng.

---

## 5. Demo Các Kịch Bản Bảo Mật

- **Kịch bản 1: Tấn công Brute-Force**
  - **Hành động:** Gửi request đăng nhập với mật khẩu sai liên tục.
  - **Kết quả:** Sau vài lần `401 Unauthorized`, bạn sẽ nhận được `429 Too Many Requests`. **Cơ chế Rate Limiting đã hoạt động.**

- **Kịch bản 2: Gửi Dữ Liệu Sai Định Dạng**
  - **Hành động:** Gửi request đăng nhập thiếu trường `password`.
  - **Kết quả:** Bạn sẽ nhận được `400 Bad Request`. **Cơ chế Validation Payload đã hoạt động.**

- **Kịch bản 3: Giám Sát Tấn Công Trên Kibana**
  - **Hành động:** Truy cập Kibana trên VPS (`http://<IP_VPS>:5601`).
  - **Kết quả:**
    - Vào **Discover**, bạn có thể tìm kiếm và lọc các log có `event.status: 429` để thấy chính xác các request đã bị chặn bởi Rate Limiting.
    - Bạn có thể tạo biểu đồ để trực quan hóa tỷ lệ các loại lỗi.
  > 📖 **Lưu ý:** Để có hướng dẫn chi tiết về cách tạo Data View và Visualize, vui lòng xem file **[KIBANA_GUIDE.md](./KIBANA_GUIDE.md)**.

---

## 6. Tài Liệu Tham Khảo Thêm

- **[PROJECT_GUIDE.md](./PROJECT_GUIDE.md):** Cẩm nang toàn diện nhất, bao gồm kịch bản thuyết trình chi tiết.
- **[SETUP_REMOTE_INFRA.md](./SETUP_REMOTE_INFRA.md):** Hướng dẫn cài đặt VPS.
- **[POSTMAN_TESTING_GUIDE.md](./POSTMAN_TESTING_GUIDE.md):** Hướng dẫn kiểm thử bằng Postman.
- **[KIBANA_GUIDE.md](./KIBANA_GUIDE.md):** Hướng dẫn sử dụng Kibana.
