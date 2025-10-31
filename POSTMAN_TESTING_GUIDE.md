# Hướng Dẫn Kiểm Thử API Với Postman

Tài liệu này hướng dẫn cách sử dụng Postman để kiểm thử các kịch bản bảo mật chính của hệ thống API Gateway.

---

## 1. Kịch Bản 1: Đăng Nhập Thành Công

Kịch bản này kiểm tra luồng xác thực cơ bản với Keycloak.

- **Request:**
  ```http
  POST /auth/login
  Host: http://localhost:8000
  Content-Type: application/json

  {
    "username": "demo",
    "password": "demo123"
  }
  ```
- **Thiết lập Postman:**
  - **Method:** `POST`
  - **URL:** `http://localhost:8000/auth/login`
  - **Headers:** Thêm một header với `Key: Content-Type` và `Value: application/json`.
  - **Body:** Chọn tab `Body` -> `raw` -> `JSON` và dán nội dung JSON vào.
- **Kết quả mong đợi (Status 201 Created):**
  ```json
  {
    "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 300
  }
  ```
- **Hành động tiếp theo:** Copy giá trị `access_token` để sử dụng cho các kịch bản tiếp theo.

---

## 2. Kịch Bản 2: Truy Cập API Được Bảo Vệ (Thành Công)

Kịch bản này kiểm tra khả năng xác thực token JWT của Kong Gateway.

- **Request:**
  ```http
  GET /api/me
  Host: http://localhost:8000
  Authorization: Bearer <YOUR_ACCESS_TOKEN>
  ```
- **Thiết lập Postman:**
  - **Method:** `GET`
  - **URL:** `http://localhost:8000/api/me`
  - **Authorization:** Chọn tab `Authorization` -> `Type: Bearer Token` và dán `access_token` đã copy từ kịch bản 1 vào ô `Token`.
- **Kết quả mong đợi (Status 200 OK):**
  ```json
  {
    "sub": "...",
    "preferred_username": "demo",
    "email": "demo@example.com"
  }
  ```

---

## 3. Kịch Bản 3: Truy Cập API Không Có Token (Thất Bại)

Kịch bản này chứng minh Gateway sẽ chặn các truy cập không hợp lệ.

- **Request:**
  ```http
  GET /api/me
  Host: http://localhost:8000
  ```
- **Thiết lập Postman:**
  - **Method:** `GET`
  - **URL:** `http://localhost:8000/api/me`
  - **Authorization:** Chọn `Type: No Auth`.
- **Kết quả mong đợi (Status 401 Unauthorized):**
  ```json
  {
    "message": "No API key found in request"
  }
  ```

---

## 4. Kịch Bản 4: Tấn Công Brute-Force (Bị Chặn)

Kịch bản này chứng minh khả năng chống tấn công của cơ chế Rate Limiting.

- **Hành động:**
  1. Lấy lại request **Đăng Nhập** từ Kịch Bản 1.
  2. Thay đổi mật khẩu thành một giá trị sai (ví dụ: `"wrongpassword"`).
  3. Gửi request này liên tục 5-6 lần.
- **Kết quả mong đợi:**
  - Vài request đầu tiên sẽ trả về `401 Unauthorized`.
  - Các request tiếp theo sẽ trả về `429 Too Many Requests`.

---

## 5. Kịch Bản 5: Gửi Dữ Liệu Sai Định Dạng (Bị Chặn)

Kịch bản này chứng minh khả năng validation payload của Gateway.

- **Hành động:**
  1. Lấy lại request **Đăng Nhập** từ Kịch Bản 1.
  2. Trong phần Body, xóa trường `"password"`.
- **Kết quả mong đợi (Status 400 Bad Request):**
  ```json
  {
    "message": "Invalid credential format"
  }
