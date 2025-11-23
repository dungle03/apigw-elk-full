# Phân Tích Chi Tiết Dự Án: API Gateway Security Service

## 1. Tổng Quan Dự Án
Dự án là một hệ thống **API Gateway Security** được thiết kế để bảo vệ các backend service khỏi các mối đe dọa phổ biến (Brute-force, DDoS, dữ liệu rác) và cung cấp khả năng giám sát tập trung.

- **Mục tiêu chính:** Chuyển gánh nặng bảo mật từ Backend sang Gateway (Kong) và giám sát thời gian thực (ELK).
- **Mô hình triển khai:** **Hybrid**
  - **Local (Máy cá nhân):** Chạy **Kong Gateway** (nhẹ, xử lý traffic đầu vào).
  - **Remote (VPS):** Chạy các dịch vụ nặng (**Keycloak**, **User Service**, **ELK Stack**).

## 2. Kiến Trúc Hệ Thống

### Sơ Đồ Luồng Dữ Liệu
1.  **Client** gửi request đến **Kong Gateway** (Local).
2.  **Kong** thực hiện các kiểm tra bảo mật (Rate Limit, Validation, Auth).
    -   *Nếu thất bại:* Trả lỗi ngay lập tức (400, 401, 429).
    -   *Nếu thành công:* Chuyển tiếp request đến **User Service** (VPS).
3.  **Kong** gửi log chi tiết (async) đến **Logstash** (VPS).
4.  **Logstash** xử lý và đẩy vào **Elasticsearch**.
5.  **Kibana** hiển thị dashboard giám sát.

---

## 3. Phân Tích Chi Tiết Các Thành Phần

### A. Kong API Gateway (`kong/kong.yml`)
Đây là "người gác cổng" của hệ thống. Cấu hình được định nghĩa theo dạng Declarative (DB-less).

**Các Policy Bảo Mật Đang Áp Dụng:**
1.  **Input Validation (Lua Script):**
    -   Áp dụng cho route `/auth/login`.
    -   Kiểm tra: `username`/`password` phải là string, độ dài hợp lệ (3-50 ký tự).
    -   **Tác dụng:** Chặn ngay các request rác hoặc payload độc hại trước khi chúng chạm tới backend.
2.  **Rate Limiting:**
    -   `/auth/login`: Giới hạn **5 request/giây** (Chống Brute-force).
    -   `/api`: Giới hạn **100 request/phút** (Chống spam/DDoS).
3.  **JWT Authentication:**
    -   Áp dụng cho các route `/api`.
    -   Cơ chế: Xác thực token bằng **Public Key** của Keycloak.
    -   Kiểm tra claim `iss` (issuer) để đảm bảo token được cấp bởi đúng server Keycloak tin cậy.

### B. User Service (`usersvc/`)
Backend service được viết bằng **NestJS**.
-   **Vai trò:** Xử lý nghiệp vụ người dùng.
-   **Xác thực:** Không tự sinh token. Nó đóng vai trò trung gian (proxy) gọi sang Keycloak để lấy token khi user đăng nhập.
-   **Dependencies:** Sử dụng `axios` để gọi Keycloak, `class-validator` để validate dữ liệu (lớp bảo vệ thứ 2).

### C. ELK Stack (Giám Sát)
Hệ thống giám sát tập trung đặt tại VPS.

1.  **Logstash (`logstash/pipeline/logstash.conf`):**
    -   Nhận log từ Kong qua HTTP (port 8081).
    -   **Enrichment (Làm giàu dữ liệu):**
        -   Phân loại sự cố: Gán nhãn `blocked: rate_limit` (nếu status 429), `blocked: unauthorized` (nếu status 401/403).
        -   GeoIP: Xác định vị trí địa lý từ IP người dùng.
        -   Trích xuất các chỉ số latency (độ trễ) để đo hiệu năng.
2.  **Elasticsearch & Kibana:**
    -   Lưu trữ và hiển thị dữ liệu. Dashboard giúp phát hiện tấn công brute-force hoặc bất thường về traffic.

### D. Keycloak
-   Đóng vai trò Identity Provider (IdP).
-   Quản lý user và cấp phát JWT Token.
-   Kong chỉ việc verify token dựa trên Public Key của Keycloak mà không cần gọi trực tiếp đến Keycloak (giảm độ trễ).

---

## 4. Điểm Mạnh Của Dự Án
1.  **Defense in Depth (Bảo mật nhiều lớp):**
    -   Lớp 1 (Kong): Chặn request sai định dạng, spam.
    -   Lớp 2 (NestJS): Validate nghiệp vụ.
2.  **Hiệu Năng Cao:**
    -   Validation và Rate Limiting thực hiện tại Gateway (viết bằng Lua/Nginx) cực nhanh.
    -   Backend không bị quá tải bởi các request rác.
3.  **Khả Năng Quan Sát (Observability):**
    -   Biết chính xác ai đang tấn công, từ đâu, và tấn công loại gì thông qua ELK.

## 5. Đề Xuất Cải Tiến (Nếu Cần)
-   **Circuit Breaker:** Cấu hình thêm Circuit Breaker trong Kong để ngắt kết nối nếu Backend quá tải hoặc chết.
-   **Caching:** Thêm plugin Proxy Cache cho các API đọc dữ liệu (GET) để giảm tải cho Backend.
