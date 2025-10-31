# Hướng Dẫn Giám Sát API Với Kibana

Tài liệu này hướng dẫn cách sử dụng Kibana để theo dõi, phân tích và trực quan hóa log từ Kong API Gateway trong dự án.

---

## 1. Truy Cập Kibana

1.  Đảm bảo các dịch vụ trên VPS của bạn đang chạy.
2.  Mở trình duyệt và truy cập vào địa chỉ: `http://<IP_VPS>:5601`.
3.  Bạn sẽ được chuyển đến giao diện chính của Kibana.

---

## 2. Tạo Data View (Chỉ làm lần đầu tiên)

Để Kibana có thể đọc được log, bạn cần chỉ cho nó biết nơi tìm kiếm dữ liệu.

1.  Click vào menu **☰** (góc trên bên trái).
2.  Đi đến **Management > Stack Management**.
3.  Trong mục **Kibana**, chọn **Data Views**.
4.  Click **Create data view**.
5.  Điền các thông tin sau:
    *   **Name:** `kong-logs` (hoặc tên bạn muốn)
    *   **Index pattern:** `kong-logs-*` (Đây là mẫu tên mà Logstash dùng để tạo index trong Elasticsearch)
    *   **Timestamp field:** `@timestamp`
6.  Click **Save data view to Kibana**.

---

## 3. Khám Phá Log (Discover)

Đây là công cụ chính để bạn xem và tìm kiếm log trong thời gian thực.

1.  Click vào menu **☰** -> **Analytics > Discover**.
2.  Ở góc trên bên trái, đảm bảo bạn đã chọn data view `kong-logs`.
3.  Ở góc trên bên phải, chọn khoảng thời gian bạn muốn xem (ví dụ: **Last 15 minutes**).
4.  Click nút **Refresh** để xem các log mới nhất.

### Các Kỹ Thuật Lọc Log Hữu Ích

Bạn có thể sử dụng thanh tìm kiếm KQL (Kibana Query Language) ở trên cùng để lọc chính xác các log bạn cần.

*   **Tìm các cuộc tấn công Brute-Force (bị rate limit):**
    ```kql
    event.status: 429
    ```

*   **Tìm các request đăng nhập thất bại (sai mật khẩu):**
    ```kql
    event.route: "login-route" and event.status: 401
    ```

*   **Tìm các request bị từ chối do sai định dạng payload:**
    ```kql
    event.route: "login-route" and event.status: 400
    ```

*   **Xem hoạt động của một địa chỉ IP cụ thể:**
    ```kql
    event.client_ip: "123.45.67.89"
    ```

*   **Xem tất cả các request đến API được bảo vệ:**
    ```kql
    event.route: "user-api-route"
    ```

---

## 4. Trực Quan Hóa Dữ Liệu (Visualize)

Biến dữ liệu log thành biểu đồ để có cái nhìn tổng quan.

**Ví dụ: Tạo biểu đồ tròn thể hiện tỷ lệ các HTTP Status Code**

1.  Click vào menu **☰** -> **Analytics > Visualize Library**.
2.  Click **Create visualization**.
3.  Chọn loại biểu đồ là **Pie**.
4.  Chọn data source là `kong-logs-*`.
5.  Trong bảng cấu hình bên phải:
    *   Dưới mục **Buckets**, click **Add**.
    *   Chọn **Slice by > Terms**.
    *   Trong ô **Field**, chọn `event.status`.
    *   Click nút **Update** (hoặc đợi nó tự cập nhật).
6.  Bạn sẽ thấy một biểu đồ tròn hiển thị tỷ lệ của các status code `201`, `401`, `429`, `400`...
7.  Click **Save** ở góc trên bên phải để lưu lại biểu đồ này cho các lần xem sau.

Bằng cách này, bạn có thể nhanh chóng xây dựng các dashboard an ninh để theo dõi sức khỏe và các mối đe dọa đối với hệ thống API của mình.
