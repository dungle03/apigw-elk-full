# 🚀 HƯỚNG DẪN CHẠY PROJECT TỪ A-Z

## 📋 Mục lục
- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Bước 1: Chuẩn bị môi trường](#bước-1-chuẩn-bị-môi-trường)
- [Bước 2: Khởi động hệ thống](#bước-2-khởi-động-hệ-thống)
- [Bước 3: Cấu hình Keycloak](#bước-3-cấu-hình-keycloak)
- [Bước 4: Test API](#bước-4-test-api)
- [Bước 5: Xem logs trên Kibana](#bước-5-xem-logs-trên-kibana)
- [Bước 6: Load Testing với k6](#bước-6-load-testing-với-k6)
- [Troubleshooting](#troubleshooting)
- [Tắt hệ thống](#tắt-hệ-thống)

---

## ⚙️ Yêu cầu hệ thống

### Windows (PowerShell)
- ✅ Docker Desktop 20.10+ (đã cài đặt và đang chạy)
- ✅ Docker Compose v2+
- ✅ PowerShell 5.1+ hoặc PowerShell Core 7+
- ✅ k6 (optional - cho load testing)
- ✅ RAM tối thiểu: 8GB (khuyến nghị 16GB)

### Kiểm tra Docker
```powershell
# Kiểm tra Docker version
docker --version
# Output: Docker version 20.10+ hoặc cao hơn

# Kiểm tra Docker Compose
docker compose version
# Output: Docker Compose version v2.0+ hoặc cao hơn

# Kiểm tra Docker đang chạy
docker ps
# Không có lỗi = Docker đang hoạt động
```

---

## 🔧 Bước 1: Chuẩn bị môi trường

### 1.1. Clone hoặc mở project
```powershell
cd C:\path\to\your\project\apigw-elk-full
```

### 1.2. Dọn dẹp containers cũ (nếu có)
```powershell
# Dừng và xóa tất cả containers và volumes cũ
docker compose down -v

# Kiểm tra không còn containers nào đang chạy
docker compose ps
```

---

## 🚀 Bước 2: Khởi động hệ thống

### 2.1. Build và khởi động tất cả services
```powershell
# Build images và start containers ở chế độ detached (nền)
docker compose up -d --build
```

**Output mong đợi:**
```
[+] Running 11/11
 ✔ Network apigw-elk-full_default            Created
 ✔ Volume apigw-elk-full_keycloak-db         Created
 ✔ Volume apigw-elk-full_esdata              Created
 ✔ Container apigw-elk-full-elasticsearch-1  Started
 ✔ Container apigw-elk-full-keycloak-db-1    Started
 ✔ Container apigw-elk-full-usersvc-1        Started
 ✔ Container apigw-elk-full-logstash-1       Started
 ✔ Container apigw-elk-full-kibana-1         Started
 ✔ Container apigw-elk-full-keycloak-1       Started
 ✔ Container apigw-elk-full-kong-1           Started
```

### 2.2. Kiểm tra trạng thái containers
```powershell
docker compose ps
```

**Tất cả services phải ở trạng thái "Up" hoặc "Up (healthy)":**
- ✅ usersvc (port 3000)
- ✅ kong (ports 8000, 8001, 8443)
- ✅ keycloak (port 8080)
- ✅ keycloak-db (port 5432 internal)
- ✅ elasticsearch (port 9200)
- ✅ logstash (port 8081)
- ✅ kibana (port 5601)

### 2.3. Đợi services khởi động hoàn toàn
```powershell
# Đợi 60 giây cho Keycloak và Elasticsearch khởi động
Write-Host "⏳ Đang đợi services khởi động (60 giây)..."
Start-Sleep -Seconds 60
Write-Host "✅ Hoàn tất!"
```

### 2.4. Kiểm tra logs Keycloak
```powershell
# Xem logs Keycloak để đảm bảo realm đã được import
docker compose logs keycloak | Select-String "import"
```

**Output mong đợi:**
```
keycloak-1  | INFO  [org.keycloak.exportimport...] Realm 'demo' imported
keycloak-1  | INFO  [org.keycloak.services] Import finished successfully
```

---

## 🔑 Bước 3: Cấu hình Keycloak

### 3.1. Lấy Admin Token
```powershell
$adminToken = (Invoke-RestMethod -Uri "http://localhost:8080/realms/master/protocol/openid-connect/token" `
  -Method POST `
  -ContentType "application/x-www-form-urlencoded" `
  -Body "username=admin&password=admin&grant_type=password&client_id=admin-cli").access_token

Write-Host "✅ Đã lấy admin token: $($adminToken.Substring(0,50))..."
```

### 3.2. Lấy User ID của user demo
```powershell
$headers = @{ Authorization = "Bearer $adminToken" }
$users = Invoke-RestMethod -Uri "http://localhost:8080/admin/realms/demo/users?username=demo" -Headers $headers
$userId = $users[0].id

Write-Host "✅ User ID: $userId"
```

### 3.3. Cập nhật thông tin user
```powershell
$headers = @{ 
    Authorization = "Bearer $adminToken"
    "Content-Type" = "application/json" 
}

# Cập nhật firstName và lastName
$userUpdate = @{ 
    firstName = "Demo"
    lastName = "User" 
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/admin/realms/demo/users/$userId" `
  -Method PUT `
  -Headers $headers `
  -Body $userUpdate

Write-Host "✅ Đã cập nhật user profile"
```

### 3.4. Reset password cho user demo
```powershell
# Bước quan trọng: Reset password để account "fully set up"
$pwd = @{ 
    type = "password"
    value = "demo123"
    temporary = $false 
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/admin/realms/demo/users/$userId/reset-password" `
  -Method PUT `
  -Headers $headers `
  -Body $pwd

Write-Host "✅ Đã reset password cho user demo"
```

---

## 🧪 Bước 4: Test API

### 4.1. Test Login (lấy Access Token)
```powershell
# Tạo request body
$loginBody = @{ 
    username = "demo"
    password = "demo123" 
} | ConvertTo-Json

# Gọi API login qua Kong Gateway
$response = Invoke-RestMethod -Uri "http://localhost:8000/auth/login" `
  -Method POST `
  -ContentType "application/json" `
  -Body $loginBody

# Lưu token vào biến
$TOKEN = $response.access_token

Write-Host "`n✅ LOGIN THÀNH CÔNG!"
Write-Host "Token (100 ký tự đầu): $($TOKEN.Substring(0,100))..."
Write-Host "Expires in: $($response.expires_in) seconds"
```

**Output mong đợi:**
```
✅ LOGIN THÀNH CÔNG!
Token (100 ký tự đầu): eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJxN...
Expires in: 300 seconds
```

### 4.2. Test API /me (lấy thông tin user)
```powershell
# Gọi API với Bearer token
$headers = @{ Authorization = "Bearer $TOKEN" }
$meResponse = Invoke-RestMethod -Uri "http://localhost:8000/api/me" -Headers $headers

Write-Host "`n✅ THÔNG TIN USER:"
$meResponse | Format-Table -AutoSize
```

**Output mong đợi:**
```
✅ THÔNG TIN USER:

sub                                  preferred_username email
---                                  ------------------ -----
a3a20168-bb3e-4423-bf90-d19653cca722 demo               demo@example.com
```

### 4.3. Script test hoàn chỉnh (All-in-one)
```powershell
# TEST SCRIPT HOÀN CHỈNH
Write-Host "🧪 Bắt đầu test API..."

# Login
$loginBody = @{ username = "demo"; password = "demo123" } | ConvertTo-Json
$response = Invoke-RestMethod -Uri "http://localhost:8000/auth/login" `
  -Method POST -ContentType "application/json" -Body $loginBody
$TOKEN = $response.access_token

Write-Host "✅ 1. Login thành công!"

# Get user info
$headers = @{ Authorization = "Bearer $TOKEN" }
$meResponse = Invoke-RestMethod -Uri "http://localhost:8000/api/me" -Headers $headers

Write-Host "✅ 2. Lấy thông tin user thành công!"
Write-Host "`nThông tin user:"
$meResponse | ConvertTo-Json
```

---

## 📊 Bước 5: Xem logs trên Kibana

### 5.1. Truy cập Kibana Dashboard
```powershell
# Mở browser tới Kibana
Start-Process "http://localhost:5601"
```

Hoặc mở thủ công: **http://localhost:5601**

### 5.2. Tạo Data View

1. Vào **Menu (☰)** → **Management** → **Stack Management**
2. Click **Kibana** → **Data Views**
3. Click **Create data view**
4. Điền thông tin:
   - **Name**: `Kong Logs`
   - **Index pattern**: `kong-logs-*`
   - **Timestamp field**: `@timestamp`
5. Click **Save data view to Kibana**

### 5.3. Xem logs

1. Vào **Menu (☰)** → **Analytics** → **Discover**
2. Chọn Data View: `Kong Logs`
3. Xem các fields quan trọng:
   - `event.status` - HTTP status code (200, 401, 429, etc.)
   - `event.client_ip` - IP của client
   - `event.method` - HTTP method (GET, POST, etc.)
   - `event.path` - Request path
   - `event.blocked` - Lý do bị block (rate_limit, unauthorized, none)
   - `event.geoip.country_name` - Quốc gia của client (từ GeoIP)

### 5.4. Tạo Dashboard đơn giản

1. Vào **Menu (☰)** → **Analytics** → **Dashboard**
2. Click **Create dashboard**
3. Click **Create visualization**
4. Chọn visualizations:
   - **Bar Chart**: Request by Status Code
   - **Pie Chart**: Blocked Requests Distribution
   - **Line Chart**: Request Rate Over Time
   - **Data Table**: Top Client IPs

---

## ⚡ Bước 6: Load Testing với k6

### 6.1. Cài đặt k6 (nếu chưa có)

**Windows (Chocolatey):**
```powershell
choco install k6
```

**Windows (Scoop):**
```powershell
scoop install k6
```

**Windows (Manual):**
- Download từ: https://k6.io/docs/getting-started/installation/
- Extract và thêm vào PATH

### 6.2. Test với traffic hợp lệ
```powershell
# Chạy kịch bản valid traffic (login + get user info)
k6 run k6/valid.js
```

**Output mong đợi:**
```
running (1m20.0s), 000/200 VUs, 15000 complete and 0 interrupted iterations
     ✓ login ok
     ✓ me 200
     checks.........................: 100.00% ✓ 30000 ✗ 0
     http_req_duration..............: avg=45ms  min=12ms max=250ms
```

### 6.3. Test Brute-Force Attack (Rate Limiting)
```powershell
# Chạy kịch bản tấn công brute-force
k6 run k6/brute.js
```

**Output mong đợi:**
```
running (1m0.0s), 000/100 VUs, 60000 complete and 0 interrupted iterations
     ✓ blocked or unauthorized
     checks.........................: 100.00% ✓ 60000 ✗ 0
     http_req_blocked...............: many requests return 429 Too Many Requests
```

### 6.4. So sánh Gateway vs Direct Service
```powershell
# Test qua Gateway (có rate limiting)
$env:MODE="gw"
k6 run k6/brute.js

# Test trực tiếp service (không có rate limiting)
$env:MODE="base"
k6 run k6/brute.js
```

**Kết quả mong đợi:**
- Gateway mode: Nhiều response `429` (bị chặn)
- Base mode: Toàn bộ response `401` (không bị chặn)

---

## 🔍 Troubleshooting

### ❌ Lỗi: "Login failed - Invalid credentials"

**Nguyên nhân:** User chưa được cấu hình đúng trong Keycloak

**Giải pháp:**
```powershell
# Thực hiện lại Bước 3: Cấu hình Keycloak
# Đặc biệt quan trọng: Phải reset password qua Admin API
```

### ❌ Lỗi: "Cannot connect to Docker daemon"

**Giải pháp:**
```powershell
# Mở Docker Desktop
# Đợi Docker khởi động hoàn toàn
# Chạy lại: docker compose up -d --build
```

### ❌ Lỗi: Port đã được sử dụng

**Giải pháp:**
```powershell
# Kiểm tra port nào bị conflict
netstat -ano | findstr "8000 8080 5601 9200"

# Dừng process đang chiếm port hoặc thay đổi port trong docker-compose.yml
```

### ❌ Lỗi: 404 Not Found khi gọi /api/me

**Nguyên nhân:** Kong routing config sai

**Giải pháp:**
```powershell
# Kiểm tra kong.yml - đảm bảo strip_path: false cho route usersvc-all
docker compose restart kong
```

### ❌ Keycloak không import realm

**Giải pháp:**
```powershell
# Đảm bảo docker-compose.yml có flag --import-realm
# command: ["start-dev", "--import-realm"]

# Hoặc import thủ công:
docker compose exec keycloak /opt/keycloak/bin/kc.sh import --file /opt/keycloak/data/import/realm.json
```

### ❌ Xem logs để debug

```powershell
# Xem logs của tất cả services
docker compose logs

# Xem logs của một service cụ thể
docker compose logs usersvc
docker compose logs kong
docker compose logs keycloak

# Xem logs realtime (follow)
docker compose logs -f usersvc

# Xem 50 dòng cuối
docker compose logs --tail 50 keycloak
```

---

## 🛑 Tắt hệ thống

### Dừng containers (giữ lại data)
```powershell
docker compose stop
```

### Dừng và xóa containers (giữ lại volumes)
```powershell
docker compose down
```

### Xóa hoàn toàn (bao gồm volumes)
```powershell
# ⚠️ CẢNH BÁO: Lệnh này sẽ xóa tất cả dữ liệu
docker compose down -v
```

### Xem resource usage
```powershell
# Xem dung lượng volumes
docker system df

# Xem chi tiết containers
docker stats
```

---

## 📚 Tham khảo thêm

### URLs quan trọng
| Service | URL | Credentials |
|---------|-----|-------------|
| Kong Gateway | http://localhost:8000 | - |
| Kong Admin API | http://localhost:8001 | - |
| Keycloak Admin | http://localhost:8080/admin | admin/admin |
| Kibana Dashboard | http://localhost:5601 | - |
| Elasticsearch | http://localhost:9200 | - |
| User Service (Direct) | http://localhost:3000 | - |

### Credentials
- **Keycloak Admin**: `admin` / `admin`
- **Demo User**: `demo` / `demo123`
- **Realm**: `demo`
- **Client ID**: `usersvc-client`

### File cấu hình quan trọng
- `docker-compose.yml` - Docker services configuration
- `kong/kong.yml` - Kong Gateway routes & plugins
- `keycloak/realm-export.json` - Keycloak realm & user template
- `logstash/pipeline/logstash.conf` - Log processing pipeline
- `usersvc/openapi.yml` - OpenAPI schema validation

---

## 🎯 Checklist hoàn thành

- [ ] Docker Desktop đã cài đặt và đang chạy
- [ ] Đã clone/download project
- [ ] Đã chạy `docker compose up -d --build`
- [ ] Tất cả 7 containers đang running
- [ ] Đã cấu hình user trong Keycloak (Bước 3)
- [ ] Test login thành công (HTTP 200)
- [ ] Test /api/me thành công (HTTP 200)
- [ ] Đã truy cập được Kibana (http://localhost:5601)
- [ ] Đã tạo Data View trong Kibana
- [ ] (Optional) Đã chạy k6 load test

---

## 💡 Tips

### Restart nhanh một service
```powershell
docker compose restart kong
docker compose restart keycloak
docker compose restart usersvc
```

### Rebuild một service cụ thể
```powershell
docker compose up -d --build usersvc
```

### Xem environment variables
```powershell
docker compose exec usersvc env
docker compose exec keycloak env
```

### Export logs ra file
```powershell
docker compose logs > logs.txt
docker compose logs usersvc > usersvc-logs.txt
```

### Backup volumes
```powershell
# Backup Elasticsearch data
docker run --rm -v apigw-elk-full_esdata:/data -v ${PWD}:/backup alpine tar czf /backup/es-backup.tar.gz /data

# Backup Keycloak database
docker compose exec keycloak-db pg_dump -U keycloak keycloak > keycloak-backup.sql
```

---

**📝 Tác giả:** API Gateway Security Demo Project  
**📅 Cập nhật:** October 17, 2025  
**🔖 Version:** 1.0

---

## 🚨 Lưu ý quan trọng

1. ⚠️ **Không sử dụng configuration này trong production**
   - Passwords được hardcode
   - Security được đơn giản hóa cho mục đích demo
   - Không có HTTPS/TLS

2. 🔒 **Trong production cần thêm:**
   - HTTPS/TLS cho tất cả endpoints
   - Strong passwords và secrets management (Vault, etc.)
   - Network isolation và firewalls
   - Monitoring và alerting
   - Backup và disaster recovery
   - Rate limiting và DDoS protection tốt hơn
   - Log rotation và retention policies

3. 💻 **Resource requirements:**
   - Minimum: 8GB RAM, 20GB disk space
   - Recommended: 16GB RAM, 50GB disk space
   - Project sử dụng ~4-5GB RAM khi chạy đầy đủ

---

**🎉 Chúc bạn học tốt và demo thành công!**
