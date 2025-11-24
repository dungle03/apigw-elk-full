# Sơ Đồ Hệ Thống API Gateway Security Service

Tài liệu này chứa các sơ đồ chi tiết về luồng hoạt động và kiến trúc của hệ thống.

---

## 1. Sequence Diagram - Luồng Đăng Nhập (Login Flow)

Sơ đồ dưới đây mô tả chi tiết quá trình xác thực người dùng từ khi gửi thông tin đăng nhập cho đến khi nhận được JWT token.

```mermaid
sequenceDiagram
    participant C as 👤 Client
    participant K as 🦍 Kong Gateway
    participant U as 🚀 User Service
    participant KC as 🔑 Keycloak
    participant L as 📥 Logstash

    Note over C,KC: Bước 1: Client gửi thông tin đăng nhập
    C->>+K: POST /auth/login<br/>{username, password}
    
    Note over K: Kiểm tra Rate Limit (5 req/s)
    alt Rate Limit Exceeded
        K-->>C: ❌ 429 Too Many Requests
    else Within Limit
        Note over K: Validate Payload (Lua Script)
        alt Invalid Payload
            K-->>C: ❌ 400 Bad Request
        else Valid Payload
            K->>+U: Forward Request<br/>{username, password}
            
            Note over U,KC: Bước 2: User Service lấy token từ Keycloak
            U->>+KC: POST /realms/myrealm/protocol/openid-connect/token<br/>grant_type=password
            
            Note over KC: Xác thực thông tin đăng nhập
            alt Invalid Credentials
                KC-->>U: ❌ 401 Unauthorized
                U-->>K: 401 Unauthorized
                K-->>C: ❌ 401 Unauthorized
            else Valid Credentials
                KC-->>-U: ✅ 200 OK<br/>{access_token, refresh_token}
                
                Note over U: Bước 3: Trả token về client
                U-->>-K: 200 OK<br/>{access_token}
                K-->>-C: ✅ 200 OK<br/>{access_token}
            end
        end
    end
    
    Note over K,L: Bước 4: Ghi log (Async)
    K--)L: HTTP Log<br/>(status, latency, IP)
```

### Giải Thích Chi Tiết

#### 🔹 Bước 1: Client Gửi Thông Tin Đăng Nhập
*   Client gửi `POST /auth/login` với body chứa `username` và `password`.
*   Request đầu tiên đến **Kong Gateway** (Port 8000).

#### 🔹 Bước 2: Kong Kiểm Tra Bảo Mật
*   **Rate Limiting:** Kiểm tra xem IP này đã vượt quá 5 request/giây chưa.
    *   Nếu vượt → Trả về `429 Too Many Requests`.
*   **Payload Validation:** Dùng Lua script kiểm tra cấu trúc JSON.
    *   Nếu thiếu `username` hoặc `password` → Trả về `400 Bad Request`.

#### 🔹 Bước 3: User Service Xác Thực Với Keycloak
*   Kong forward request đến **User Service** (Port 3000).
*   User Service **không tự tạo token**, thay vào đó:
    *   Gọi API của Keycloak: `POST /realms/myrealm/protocol/openid-connect/token`.
    *   Gửi `grant_type=password`, `username`, `password`.

#### 🔹 Bước 4: Keycloak Trả Về Token
*   Nếu thông tin đúng → Keycloak tạo và trả về `access_token` (JWT).
*   User Service nhận token và forward về cho Client qua Kong.

#### 🔹 Bước 5: Ghi Log (Async)
*   Kong đồng thời gửi log (status code, latency, IP) đến Logstash.
*   Log này sau đó được lưu vào Elasticsearch và hiển thị trên Kibana.

---

## 2. Sequence Diagram - Luồng Truy Cập API (Với JWT)

```mermaid
sequenceDiagram
    participant C as 👤 Client
    participant K as 🦍 Kong Gateway
    participant U as 🚀 User Service
    participant KC as 🔑 Keycloak

    Note over C,KC: Client đã có access_token từ login
    C->>+K: GET /api/me<br/>Authorization: Bearer {token}
    
    Note over K: Bước 1: Xác thực JWT
    K->>K: Verify Token Signature<br/>(Using Keycloak Public Key)
    
    alt Invalid Token
        K-->>C: ❌ 401 Unauthorized
    else Valid Token
        Note over K: Bước 2: Kiểm tra Rate Limit
        alt Rate Limit Exceeded
            K-->>C: ❌ 429 Too Many Requests
        else Within Limit
            K->>+U: GET /api/me<br/>Authorization: Bearer {token}
            
            Note over U: Bước 3: User Service xử lý
            U->>U: Decode JWT<br/>Extract user info
            
            U-->>-K: 200 OK<br/>{user_info}
            K-->>-C: ✅ 200 OK<br/>{user_info}
        end
    end
```

### Giải Thích

1.  **Client gửi token:** Trong header `Authorization: Bearer <token>`.
2.  **Kong xác thực JWT:**
    *   Dùng public key của Keycloak (đã được cấu hình trong `kong.yml`).
    *   Kiểm tra chữ ký (signature) và thời hạn (exp).
3.  **Nếu hợp lệ:** Forward request đến User Service.
4.  **User Service:** Decode JWT để lấy thông tin user và trả về.

---

## 3. Flowchart - Xử Lý Request Tổng Quát

```mermaid
flowchart TD
    Start([Client Request]) --> RateCheck{Check<br/>Rate Limit}
    
    RateCheck -->|Exceeded| Block1[❌ Return 429]
    RateCheck -->|OK| PayloadCheck{Validate<br/>Payload}
    
    PayloadCheck -->|Invalid| Block2[❌ Return 400]
    PayloadCheck -->|Valid| AuthCheck{Need<br/>Auth?}
    
    AuthCheck -->|Yes| JWTCheck{Valid<br/>JWT?}
    AuthCheck -->|No| Forward
    
    JWTCheck -->|Invalid| Block3[❌ Return 401]
    JWTCheck -->|Valid| Forward[✅ Forward to Backend]
    
    Forward --> Backend[Backend Processing]
    Backend --> Response[Return Response]
    
    Response --> Log[📝 Send Log to Logstash]
    Log --> End([End])
    
    Block1 --> Log
    Block2 --> Log
    Block3 --> Log
    
    style Start fill:#e3f2fd,stroke:#1976d2
    style End fill:#e8f5e9,stroke:#388e3c
    style Block1 fill:#ffebee,stroke:#c62828
    style Block2 fill:#ffebee,stroke:#c62828
    style Block3 fill:#ffebee,stroke:#c62828
    style Forward fill:#e8f5e9,stroke:#388e3c
```

---

## 4. Component Diagram - Kiến Trúc Chi Tiết

```mermaid
graph TB
    subgraph Client["💻 Client Layer"]
        Web[Web App]
        Mobile[Mobile App]
        Postman[Postman/Curl]
    end
    
    subgraph Local["🏠 Local Machine"]
        Kong[Kong Gateway<br/>:8000]
        
        subgraph Plugins
            RL[Rate Limiting<br/>Plugin]
            JWT[JWT Auth<br/>Plugin]
            Log[HTTP Log<br/>Plugin]
        end
    end
    
    subgraph VPS["☁️ Remote VPS"]
        subgraph App["Application Layer"]
            UserSvc[User Service<br/>:3000<br/>NestJS]
        end
        
        subgraph Auth["Authentication Layer"]
            KC[Keycloak<br/>:8080]
            KCDB[(Keycloak DB<br/>PostgreSQL)]
        end
        
        subgraph Monitor["Monitoring Layer"]
            LS[Logstash<br/>:8081]
            ES[(Elasticsearch<br/>:9200)]
            KB[Kibana<br/>:5601]
        end
    end
    
    Web --> Kong
    Mobile --> Kong
    Postman --> Kong
    
    Kong --> RL
    Kong --> JWT
    Kong --> Log
    
    Kong --> UserSvc
    UserSvc --> KC
    KC --> KCDB
    
    Log -.-> LS
    LS --> ES
    ES --> KB
    
    style Kong fill:#fff3e0,stroke:#f57c00,stroke-width:3px
    style UserSvc fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
    style KC fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
    style LS fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style ES fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style KB fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
```

---

## Tóm Tắt

Tài liệu này cung cấp 4 loại sơ đồ chính:

1.  **Sequence Diagram (Login):** Luồng đăng nhập chi tiết với xác thực qua Keycloak.
2.  **Sequence Diagram (API Access):** Luồng truy cập API với JWT token.
3.  **Flowchart:** Quy trình xử lý request tổng quát tại Kong Gateway.
4.  **Component Diagram:** Kiến trúc tổng thể với các thành phần và kết nối.
