# 5. TRIỂN KHAI HỆ THỐNG (IMPLEMENTATION)

Phần này mô tả chi tiết quá trình triển khai thực tế hệ thống **API Gateway Security Service** theo mô hình **Hybrid Architecture**, trong đó Kong Gateway chạy trên **Local Machine** và các dịch vụ Backend (Keycloak, User Service, ELK Stack) chạy trên **Remote VPS**. Toàn bộ hệ thống được triển khai bằng **Docker Compose** và **Declarative Configuration** để đảm bảo tính nhất quán và khả năng tái sử dụng.

---

## 5.1. Công Nghệ và Môi Trường Triển Khai

### 5.1.1. Stack Công Nghệ

| Công Nghệ | Phiên Bản | Vai Trò | Vị Trí |
|:----------|:----------|:--------|:-------|
| **Kong Gateway** | 3.7 | API Gateway, JWT Auth, Rate Limiting, Logging | Local Machine |
| **Keycloak** | 26.0 | Identity Provider (IAM), JWT Token Issuer | Remote VPS |
| **PostgreSQL** | 15 | Database cho Keycloak | Remote VPS |
| **NestJS (User Service)** | Latest | Backend API, xử lý nghiệp vụ | Remote VPS |
| **Logstash** | 8.15.2 | Thu thập và xử lý log từ Kong | Remote VPS |
| **Elasticsearch** | 8.15.2 | Lưu trữ và index log | Remote VPS |
| **Kibana** | 8.15.2 | Trực quan hóa log và monitoring | Remote VPS |
| **Docker Compose** | 2.x | Orchestration toàn bộ stack | Both |

### 5.1.2. Môi Trường Triển Khai

**Remote VPS (Ubuntu Server):**
*   **Cấu hình:** 2 vCPU, 4GB RAM
*   **Services:** Keycloak, Keycloak DB, User Service, ELK Stack
*   **Ports mở:** 3000 (UserSvc), 8080 (Keycloak), 8081 (Logstash), 9200 (Elasticsearch), 5601 (Kibana)

**Local Machine (Windows 11):**
*   **Phần mềm:** Docker Desktop (WSL2)
*   **Services:** Kong Gateway
*   **Port:** 8000 (Kong Proxy), 8001 (Kong Admin)

**Repository:**  
👉 [https://github.com/dungle03/apigw-elk-full](https://github.com/dungle03/apigw-elk-full)

---

## 5.2. Cấu Trúc Docker Compose

### 5.2.1. File `docker-compose.yml` (Chạy trên VPS)

Toàn bộ Backend và ELK Stack được định nghĩa trong file `docker-compose.yml`:

```yaml
version: "3.9"

services:
  # ==================== Keycloak Stack ====================
  keycloak-db:
    image: postgres:15
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: password
    volumes:
      - keycloak-db-data:/var/lib/postgresql/data
    networks:
      - elk-net

  keycloak:
    image: quay.io/keycloak/keycloak:26.0
    command: start-dev
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://keycloak-db:5432/keycloak
      KC_HOSTNAME: ${PUBLIC_IP}
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
    ports:
      - "8080:8080"
      - "8443:8443"
    depends_on:
      - keycloak-db
    networks:
      - elk-net

  # ==================== User Service ====================
  usersvc:
    build: ./usersvc
    environment:
      KEYCLOAK_REALM_URL: http://keycloak:8080/realms/myrealm
    ports:
      - "3000:3000"
    networks:
      - elk-net

  # ==================== ELK Stack ====================
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.15.2
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    networks:
      - elk-net

  logstash:
    image: docker.elastic.co/logstash/logstash:8.15.2
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
    ports:
      - "8081:8081"
    depends_on:
      - elasticsearch
    networks:
      - elk-net

  kibana:
    image: docker.elastic.co/kibana/kibana:8.15.2
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
    networks:
      - elk-net

networks:
  elk-net:
    driver: bridge

volumes:
  keycloak-db-data:
```

### 5.2.2. File `docker-compose.kong-only.yml` (Chạy trên Local)

Kong chạy độc lập trên máy Local:

```yaml
version: "3.9"

services:
  kong:
    image: kong/kong-gateway:3.7
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /kong/kong.yml
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
    volumes:
      - ./kong/kong.yml:/kong/kong.yml:ro
    ports:
      - "8000:8000"
      - "8443:8443"
      - "8001:8001"
      - "8444:8444"
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: "2GB"
```

---

## 5.3. Triển Khai Kong Gateway (Declarative Configuration)

Kong sử dụng **DB-less mode** với cấu hình declarative trong file `kong/kong.yml`. Điều này giúp dễ dàng quản lý và version control.

### 5.3.1. Cấu Trúc File `kong.yml`

```yaml
_format_version: "3.0"

# ==================== Consumer ====================
consumers:
  - username: keycloak-issuer
    jwt_secrets:
      - key: "https://${PUBLIC_IP}:8443/realms/myrealm"
        rsa_public_key: |
          -----BEGIN CERTIFICATE-----
          MIICnzCCAYcCBgGU...
          -----END CERTIFICATE-----

# ==================== Global Plugins ====================
plugins:
  - name: http-log
    config:
      http_endpoint: http://${PUBLIC_IP}:8081

# ==================== Services & Routes ====================
services:
  # Login Service (Rate Limit Chặt)
  - name: auth-service
    url: http://${PUBLIC_IP}:3000/auth/login
    routes:
      - name: auth-route
        paths:
          - /auth/login
        methods:
          - POST
    plugins:
      - name: request-lua-validator
        config:
          script: |
            -- Validate username và password
      - name: rate-limiting
        config:
          second: 5
          minute: 100
          policy: local

  # User API Service (JWT Required)
  - name: user-service
    url: http://${PUBLIC_IP}:3000/api
    routes:
      - name: user-route
        paths:
          - /api
    plugins:
      - name: jwt
        config:
          claims_to_verify:
            - exp
      - name: rate-limiting
        config:
          minute: 10000
          policy: local
```

### 5.3.2. Script Render Template

Để inject `PUBLIC_IP` vào `kong.yml`, sử dụng script `scripts/update-kong.ps1`:

```powershell
# Đọc PUBLIC_IP từ .env
$envFile = ".\.env"
$publicIp = (Get-Content $envFile | Select-String "PUBLIC_IP=").ToString().Split("=")[1]

# Render template
$template = Get-Content ".\kong\kong.yml.tmpl" -Raw
$output = $template -replace '\$\{PUBLIC_IP\}', $publicIp
Set-Content ".\kong\kong.yml" $output

Write-Host "✅ Rendered kong.yml with PUBLIC_IP=$publicIp"
```

**Chạy lệnh:**
```powershell
pwsh -File .\scripts\update-kong.ps1
docker compose -f docker-compose.kong-only.yml up -d --force-recreate
```

---

## 5.4. Triển Khai Keycloak (Identity Provider)

### 5.4.1. Khởi động Keycloak

Trên VPS, chạy:
```bash
docker compose up -d keycloak keycloak-db
```

Truy cập Admin Console: `http://<VPS_IP>:8080`

### 5.4.2. Tạo Realm

1.  Đăng nhập Admin Console (admin/admin)
2.  Tạo Realm mới: `myrealm`
3.  Realm Settings → General → Frontend URL: `http://<VPS_IP>:8080`

### 5.4.3. Tạo Client

*   Client ID: `usersvc-client`
*   Client Protocol: `openid-connect`
*   Access Type: `public`
*   Valid Redirect URIs: `*`
*   Web Origins: `*`

### 5.4.4. Tạo User Demo

*   Username: `demo`
*   Email: `demo@example.com`
*   Password: `demo123` (tắt Temporary)

### 5.4.5. Cấu Hình Token Lifespan

Realm Settings → Tokens:
*   Access Token Lifespan: **60 minutes** (thay vì 5 phút mặc định)
*   Refresh Token Lifespan: **60 minutes**

### 5.4.6. Lấy Public Key

Kong cần public key để verify JWT. Lấy từ endpoint:

```
GET https://<VPS_IP>:8443/realms/myrealm/protocol/openid-connect/certs
```

Copy phần `x5c` và chuyển thành PEM format, rồi paste vào `kong.yml`.

---

## 5.5. Triển Khai User Service (NestJS Backend)

### 5.5.1. Cấu Trúc Code

```
usersvc/
├── src/
│   ├── auth.controller.ts   # /auth/login, /api/me
│   ├── auth.service.ts      # Gọi Keycloak để lấy token
│   └── main.ts
├── Dockerfile
└── package.json
```

### 5.5.2. Code Key: `auth.service.ts`

```typescript
import { Injectable } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class AuthService {
  private kcRealmBase = process.env.KEYCLOAK_REALM_URL;

  async loginWithKeycloak(username: string, password: string) {
    try {
      const response = await axios.post(
        `${this.kcRealmBase}/protocol/openid-connect/token`,
        new URLSearchParams({
          grant_type: 'password',
          client_id: 'usersvc-client',
          username,
          password,
        }),
      );
      return response.data; // {access_token, refresh_token}
    } catch (error) {
      throw new Error('Invalid credentials');
    }
  }
}
```

### 5.5.3. Build và Deploy

```bash
cd usersvc
docker build -t apigw-elk-full-usersvc .
docker compose up -d usersvc
```

---

## 5.6. Triển Khai ELK Stack (Logging & Monitoring)

### 5.6.1. Logstash Pipeline

File `logstash/pipeline/logstash.conf`:

```ruby
input {
  http {
    port => 8081
    codec => json
  }
}

filter {
  json {
    source => "message"
  }

  # Extract fields
  mutate {
    add_field => {
      "client_ip" => "%{[request][headers][x-forwarded-for]}"
      "status_code" => "%{[response][status]}"
      "latency_ms" => "%{[latencies][proxy]}"
    }
  }

  # GeoIP
  geoip {
    source => "client_ip"
    target => "geo"
  }

  # Classify Blocked Requests
  if [status_code] == "429" {
    mutate { add_tag => ["rate_limited"] }
  }
  if [status_code] == "401" {
    mutate { add_tag => ["unauthorized"] }
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "kong-logs-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
```

### 5.6.2. Khởi động ELK Stack

```bash
docker compose up -d elasticsearch logstash kibana
```

### 5.6.3. Cấu hình Kibana

1.  Truy cập: `http://<VPS_IP>:5601`
2.  Stack Management → Index Patterns → Create: `kong-logs-*`
3.  Discover → Chọn index pattern `kong-logs-*`

---

## 5.7. Quy Trình Triển Khai Hoàn Chỉnh

### Bước 1: Chuẩn Bị VPS

```bash
# Trên VPS Ubuntu
sudo apt update
sudo apt install docker.io docker-compose git -y

# Clone repo
git clone https://github.com/dungle03/apigw-elk-full.git
cd apigw-elk-full

# Tạo .env
cp .env.example .env
nano .env  # Sửa PUBLIC_IP=<VPS_IP>
```

### Bước 2: Deploy Backend Stack

```bash
# Build usersvc trước
docker compose build usersvc

# Start tất cả services
docker compose up -d

# Kiểm tra
docker compose ps
```

Output mong đợi:
```
NAME                STATUS              PORTS
keycloak            Up 2 minutes        0.0.0.0:8080->8080/tcp
keycloak-db         Up 2 minutes        5432/tcp
usersvc             Up 2 minutes        0.0.0.0:3000->3000/tcp
elasticsearch       Up 2 minutes        0.0.0.0:9200->9200/tcp
logstash            Up 2 minutes        0.0.0.0:8081->8081/tcp
kibana              Up 2 minutes        0.0.0.0:5601->5601/tcp
```

### Bước 3: Cấu hình Keycloak

1.  Truy cập: `http://<VPS_IP>:8080`
2.  Tạo Realm `myrealm`
3.  Tạo User `demo/demo123`
4.  Lấy Public Key từ JWKS endpoint
5.  Cấu hình Token Lifespan: 60 phút

### Bước 4: Deploy Kong trên Local

```powershell
# Trên Windows
cd apigw-elk-full

# Tạo .env
Copy-Item .env.example .env
notepad .env  # Sửa PUBLIC_IP=<VPS_IP>

# Render kong.yml
pwsh -File .\scripts\update-kong.ps1

# Start Kong
docker compose -f docker-compose.kong-only.yml up -d --force-recreate

# Verify
docker compose -f docker-compose.kong-only.yml ps
```

### Bước 5: Kiểm Tra Hoạt Động

**Test Login:**
```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"demo","password":"demo123"}'
```

**Test API với Token:**
```bash
TOKEN="<access_token_received>"
curl http://localhost:8000/api/me \
  -H "Authorization: Bearer $TOKEN"
```

**Kiểm tra Log trên Kibana:**
```
http://<VPS_IP>:5601
→ Discover → Chọn index pattern `kong-logs-*`
```

---

## 5.8. Các Điểm Lưu Ý Khi Triển Khai

### 5.8.1. Vấn Đề Networking

*   Kong chạy trên Local **không thể** dùng hostname `keycloak` hay `usersvc` vì chúng nằm ở VPS.
*   **Giải pháp:** Dùng `${PUBLIC_IP}` trong `kong.yml` để trỏ đến VPS.

### 5.8.2. Firewall

Đảm bảo VPS mở các ports:
```bash
sudo ufw allow 3000/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 8081/tcp
sudo ufw allow 9200/tcp
sudo ufw allow 5601/tcp
```

### 5.8.3. HTTPS/TLS

Hiện tại sử dụng HTTP cho demo. Trong production:
*   Keycloak nên chạy với HTTPS (Let's Encrypt)
*   Kong nên enable SSL termination

### 5.8.4. Scalability

*   Nếu lượng log lớn, tăng replica Logstash
*   Elasticsearch nên chạy cluster 3 nodes
*   Kong có thể scale horizontal với DB mode

---

## 5.9. Kết Luận

Hệ thống đã được triển khai thành công theo mô hình **Hybrid Architecture** với:

✅ **Kong Gateway** (Local) đóng vai trò API Gateway  
✅ **Keycloak** (VPS) cung cấp JWT token  
✅ **User Service** (VPS) xử lý business logic  
✅ **ELK Stack** (VPS) thu thập và phân tích log  

Toàn bộ quá trình triển khai được tự động hóa bằng **Docker Compose** và **Declarative Configuration**, giúp dễ dàng tái tạo môi trường và đảm bảo tính nhất quán giữa các lần chạy.
