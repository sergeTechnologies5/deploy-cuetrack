# CueTrack – Production Deployment

| URL | Service |
|---|---|
| `https://DOMAIN/` | cuetrack (operator app) |
| `https://DOMAIN/admin` | admin dashboard |
| `https://DOMAIN/company` | company dashboard |
| `https://DOMAIN/api`, `/ws` | Spring Boot backend |
| `https://pay.DOMAIN/` | customer payment portal (table QR) |
| `DOMAIN:1883` | MQTT for devices (password required) |

## 1. Prepare the server (once)
```bash
# DNS: A records  DOMAIN -> VPS_IP  and  pay.DOMAIN -> VPS_IP
scp deploy/setup-vps.sh root@VPS_IP:
ssh root@VPS_IP bash setup-vps.sh phineas
```

## 2. Get the code
```bash
ssh phineas@VPS_IP
cd /opt/cuetrack
git clone <iot-backend repo>   iot-backend
git clone <iot-dashboard repo> iot-dashboard
# copy this deploy/ folder (git repo or: scp -r deploy phineas@VPS_IP:/opt/cuetrack/)
cd deploy
cp .env.example .env && nano .env        # fill everything; openssl rand -hex 32
```

## 3. MQTT users
```bash
docker run --rm -v "$PWD/mosquitto:/m" eclipse-mosquitto:2 \
  mosquitto_passwd -c -b /m/passwd backend '<MQTT_BACKEND_PASSWORD>'
docker run --rm -v "$PWD/mosquitto:/m" eclipse-mosquitto:2 \
  mosquitto_passwd -b /m/passwd device '<device password>'
chmod 644 mosquitto/passwd
```
Put the device user/password + `DOMAIN` into `device/cuetrack.py` and reflash.

## 4. Start
```bash
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml logs -f backend
```

## Updating
```bash
cd /opt/cuetrack/iot-backend && git pull     # and/or iot-dashboard
cd ../deploy && docker compose -f docker-compose.prod.yml up -d --build backend   # or admin/company/cuetrack/pay
```

## Backups
```bash
chmod +x backup.sh
crontab -e   # 0 3 * * * /opt/cuetrack/deploy/backup.sh
# restore:
gunzip -c ../backups/db-YYYY-MM-DD.sql.gz | docker compose -f docker-compose.prod.yml exec -T postgres psql -U cuetrack -d iot-dashboard
```

## Low-RAM VPS (≤2 GB)
Building 4 Next apps on the VPS is heavy. Build one at a time:
`docker compose -f docker-compose.prod.yml build admin` … then `up -d`.
