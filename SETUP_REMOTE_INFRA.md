# Ubuntu VPS Setup for API Gateway Demo

This guide prepares a remote Ubuntu 24.04 LTS server to host the backing services (Keycloak, usersvc, ELK stack) that your local Kong gateway will consume.

## 1. Provision the Instance
- Choose an EC2 type with at least 2 vCPU and 8 GiB RAM (e.g. `m7i-flex.large`).
- Attach a 30 GiB or larger gp3 EBS volume.
- Security group: allow inbound TCP from your gateway machine on ports `22,3000,8080,8081,9200,5601` (limit source IP); optionally allow `443` if you terminate TLS.

## 2. Initial Server Prep
```bash
ssh -i <key.pem> ubuntu@<PUBLIC_IP>
sudo apt update && sudo apt upgrade -y
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
```
(Optional) enable uncomplicated firewall and open required ports:
```bash
sudo ufw allow OpenSSH
sudo ufw allow 3000/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 8081/tcp
sudo ufw allow 9200/tcp
sudo ufw allow 5601/tcp
sudo ufw enable
```

## 3. Install Docker Engine + Compose Plugin
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

## 4. Fetch Project Assets
```bash
# inside the VPS
git clone https://github.com/dungle03/apigw-elk-full.git
cd apigw-elk-full
```
If you only need the service directory, copy it from your workstation with `scp -r usersvc keycloak logstash docker-compose.yml ...`.

## 5. Configure Remote Environment
- Edit `docker-compose.yml` if you want different passwords or port mappings.
- Ensure `keycloak/realm-export.json` contains the realm configuration you expect.
- For demo data persistence, keep the default named volumes (`keycloak-db`, `esdata`).

## 6. Launch Supporting Services
Run the backing services without Kong:
```bash
docker compose up -d usersvc keycloak keycloak-db logstash elasticsearch kibana
```
Watch startup logs until each service reports healthy:
```bash
docker compose ps
docker compose logs -f keycloak
docker compose logs -f elasticsearch
```
> Nếu healthcheck của Keycloak báo `curl: executable file not found`, hãy cập nhật `docker-compose.yml` (đã đổi sẵn trong repo) sử dụng `/opt/keycloak/bin/kc.sh health --fail` thay vì `curl`, rồi `docker compose up -d keycloak` để áp dụng.

## 7. Health Checks
```bash
curl http://localhost:3000/health
curl http://localhost:8080/realms/demo/.well-known/openid-configuration
curl -X POST http://localhost:8081/kong -d '{}'
curl http://localhost:9200/_cluster/health
```
Expose the same endpoints via the public IP to confirm firewall rules:
```bash
curl http://<PUBLIC_IP>:3000/health
curl http://<PUBLIC_IP>:8080/realms/demo/.well-known/openid-configuration
```

## 8. Wire Kong Gateway to the VPS
On your local gateway machine:
1. Update every `http://<YOUR_EXTERNAL_IP_OR_DOMAIN>` placeholder in `kong/kong.yml` with `http://13.215.228.218` (or your DNS alias) and correct ports.
2. Redeploy Kong (`docker compose -f docker-compose.kong-only.yml up -d --build` or `docker compose restart kong`).
3. From inside the Kong container run `curl http://13.215.228.218:3000/health` to verify reachability.
4. Adjust `logstash/pipeline/logstash.conf` if Elasticsearch is remote (replace `elasticsearch:9200` with `http://13.215.228.218:9200`).

## 9. Demo Checklist
- Kong routes return 200 for `/auth/login` and `/api/me` using remote Keycloak/usersvc.
- Rate limiting, OIDC, and logging plugins operate correctly (check Kibana at `http://13.215.228.218:5601`).
- k6 scripts run from the gateway machine with `MODE=base UPSTREAM_HOST=http://13.215.228.218:3000` and with `MODE=gw GATEWAY_HOST=http://<GATEWAY_IP>:8000` for before/after comparisons.
- Monitor `docker stats` on the VPS to capture resource usage improvements introduced by the gateway.

## 10. Maintenance Notes
- Restart individual services with `docker compose restart <service>`.
- Backup volumes: `docker run --rm -v apigw-elk-full_esdata:/data -v $PWD:/backup alpine tar czf /backup/es-backup.tar.gz /data`.
- Shut down when idle: `docker compose down` (keep volumes) or `docker compose down -v` (wipe data).
