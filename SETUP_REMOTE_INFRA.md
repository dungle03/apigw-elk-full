# Hướng Dẫn Cài Đặt Ubuntu VPS Cho Demo API Gateway

Tài liệu này hướng dẫn cấu hình một máy chủ Ubuntu 24.04 LTS từ xa để chạy các dịch vụ nền (Keycloak, usersvc, ELK) cho Kong gateway đặt tại máy cục bộ của bạn.

## 1. Chuẩn Bị Máy EC2
- Chọn loại EC2 có tối thiểu 2 vCPU và 8 GiB RAM (gợi ý `m7i-flex.large`).
- Gắn ổ EBS gp3 dung lượng 30 GiB trở lên.
- Security group cần cho phép kết nối TCP từ máy chạy gateway vào các cổng `22,3000,8080,8081,9200,5601` (nên giới hạn theo IP nguồn). Nếu dự định bật HTTPS tại gateway có thể mở thêm `443`.

## 2. Chuẩn Bị Máy Chủ Lần Đầu
```bash
ssh -i <key.pem> ubuntu@<PUBLIC_IP>
sudo apt update && sudo apt upgrade -y
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
```
Nếu dùng UFW (không bắt buộc) hãy mở các cổng cần thiết rồi bật firewall:
```bash
sudo ufw allow OpenSSH
sudo ufw allow 3000/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 8081/tcp
sudo ufw allow 9200/tcp
sudo ufw allow 5601/tcp
sudo ufw enable
```

## 3. Cài Docker Engine & Docker Compose Plugin
```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
sudo apt install -y docker-compose-plugin
# re-login to load docker group
exit
ssh -i <key.pem> ubuntu@<PUBLIC_IP>
docker --version
docker compose version
```

## 4. Tải Mã Nguồn Dự Án
```bash
# inside the VPS
git clone https://github.com/dungle03/apigw-elk-full.git
cd apigw-elk-full
```
Nếu chỉ cần một vài thư mục dịch vụ, có thể chép trực tiếp từ máy cá nhân bằng `scp -r usersvc keycloak logstash docker-compose.yml ...`.

## 5. Điều Chỉnh Môi Trường Trên VPS
- Thay đổi `docker-compose.yml` nếu muốn cập nhật mật khẩu hay ánh xạ cổng.
- Kiểm tra `keycloak/realm-export.json` để chắc chắn realm cấu hình đúng nhu cầu.
- Giữ nguyên các volume đặt tên (`keycloak-db`, `esdata`) để lưu dữ liệu demo.

## 6. Khởi Chạy Các Dịch Vụ Hỗ Trợ
Chạy toàn bộ dịch vụ nền (chưa cần khởi động Kong):
```bash
docker compose up -d usersvc keycloak keycloak-db logstash elasticsearch kibana
```
Theo dõi log tới khi các container báo healthy:
```bash
docker compose ps
docker compose logs -f keycloak
docker compose logs -f elasticsearch
```
> Nếu healthcheck của Keycloak báo lỗi `curl: executable file not found`, mã nguồn đã cập nhật sang lệnh `kc.sh tools health --fail-on-critical`. Sau khi pull bản mới hãy chạy `docker compose up -d keycloak` để cập nhật container.

## 7. Kiểm Tra Sức Khỏe & Quản Lý User

### 7.1 Gọi Nhanh Các Dịch Vụ Nội Bộ
```bash
# usersvc không có endpoint /health nên gọi login để chắc container trả lời
curl -i -X POST http://localhost:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo","password":"demo123"}'

# Keycloak OpenID discovery
curl http://localhost:8080/realms/demo/.well-known/openid-configuration

# Logstash ingest endpoint
curl -X POST http://localhost:8081/kong -d '{}'

# Elasticsearch cluster status
curl http://localhost:9200/_cluster/health
```

### 7.2 Tạo Hoặc Đặt Lại Tài Khoản demo Trên Keycloak
```bash
# Lấy admin token
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'username=admin&password=admin&grant_type=password&client_id=admin-cli' | jq -r .access_token)

# Tạo user demo nếu chưa có (bỏ qua lỗi trùng)
curl -s -o /dev/null -w '' -X POST "http://localhost:8080/admin/realms/demo/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"username":"demo","firstName":"Demo","lastName":"User","email":"demo@example.com","enabled":true}' || true

# Lấy USER_ID
USER_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:8080/admin/realms/demo/users?username=demo" | jq -r '.[0].id')

# Bật tài khoản, xác thực email và xóa requiredActions
curl -s -X PUT "http://localhost:8080/admin/realms/demo/users/$USER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"firstName":"Demo","lastName":"User","email":"demo@example.com","emailVerified":true,"enabled":true,"requiredActions":[]}'

# Đặt lại mật khẩu cố định
curl -s -X PUT "http://localhost:8080/admin/realms/demo/users/$USER_ID/reset-password" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"type":"password","temporary":false,"value":"demo123"}'
```

### 7.3 Xóa User demo Khi Cần Dọn Dẹp
```bash
curl -s -X DELETE "http://localhost:8080/admin/realms/demo/users/$USER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 7.4 Kiểm Tra Thông Qua Public IP
```bash
curl -i -X POST http://18.136.195.180:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo","password":"demo123"}'

curl http://<PUBLIC_IP>:8080/realms/demo/.well-known/openid-configuration
```

### 7.5 Kiểm Tra Từ Máy Windows (PowerShell)
```powershell
# Đảm bảo security group/ufw mở cổng 3000 trước khi test
Test-NetConnection 18.136.195.180 -Port 3000

# Gọi usersvc trực tiếp (chuỗi JSON không cần escape kép)
curl.exe -i -X POST "http://localhost:8000/auth/login" `
  -H "Content-Type: application/json" `
  --data-raw '{"username":"demo","password":"demo123"}'
```

## 8. Kết Nối Kong Gateway Với VPS
Thao tác tại máy chạy gateway (máy cục bộ):
1. Cập nhật mọi placeholder `http://<YOUR_EXTERNAL_IP_OR_DOMAIN>` trong `kong/kong.yml` thành `http://18.136.195.180` (hoặc tên miền của bạn) và đảm bảo đúng cổng.
2. Triển khai lại Kong (`docker compose -f docker-compose.kong-only.yml up -d --build` hoặc `docker compose restart kong`).
3. Trong container Kong chạy `curl http://18.136.195.180:3000/health` để kiểm tra khả năng truy cập usersvc.
4. Nếu Elasticsearch đặt ở VPS này, giữ nguyên `logstash/pipeline/logstash.conf`. Nếu chuyển nơi khác cần sửa `hosts` thành `http://<IP_ES>:9200`.

## 9. Danh Sách Kiểm Tra Demo
- Các route của Kong trả về 200 cho `/auth/login` và `/api/me` (sử dụng Keycloak/usersvc trên VPS).
- Các plugin `pre-function` (validation), `jwt`, `rate-limiting`, `http-log` hoạt động và log hiển thị trên Kibana (`http://18.136.195.180:5601`).
- Script k6 chạy trên máy gateway với `MODE=base UPSTREAM_HOST=http://18.136.195.180:3000` và `MODE=gw GATEWAY_HOST=http://<GATEWAY_IP>:8000` để so sánh trước/sau.
- Dùng `docker stats` trên VPS để đo mức tiêu thụ tài nguyên khi có / không có gateway.

## 10. Ghi Chú Bảo Trì
- Khởi động lại một dịch vụ: `docker compose restart <service>`.
- Sao lưu volume: `docker run --rm -v apigw-elk-full_esdata:/data -v $PWD:/backup alpine tar czf /backup/es-backup.tar.gz /data`.
- Khi không sử dụng: `docker compose down` (giữ dữ liệu) hoặc `docker compose down -v` (xóa sạch volume).
