# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Phạm Thanh Sơn |
| Mã học viên | 2A202602794 |
| Repo | https://github.com/holyspirit2207/K4-L3B-DAY12-PhamThanhSon-2A202602794-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://k4-l3b-day12-phamthanhson-2a202602794-cloudservi-production.up.railway.app |
| Platform | Railway (build từ Dockerfile, Redis add-on của Railway) |
| Ngày deploy | 2026-09-29 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán (8080); domain public trỏ vào port 8080 |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | reference `${{Redis.REDIS_URL}}` tới Redis add-on của Railway (private network) |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Dán output của các lệnh trên vào đây:

```
$ curl -i <URL>/health
HTTP/1.1 200 OK
Content-Type: application/json
Date: Tue, 29 Sep 2026 16:34:23 GMT
Server: railway-hikari
x-railway-request-id: E-VkkUitSIqXm_YClt7tkg
Content-Length: 57
x-hikari-trace: hkg1.aebn
x-railway-edge: hkg1
Connection: keep-alive

{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i <URL>/ready
HTTP/1.1 200 OK
Content-Type: application/json
Date: Tue, 29 Sep 2026 16:34:23 GMT
Server: railway-hikari
x-railway-request-id: eauSuiKdQcaQ7Qi9wUFZXw
Content-Length: 31
x-hikari-trace: hkg1.hn7d
x-railway-edge: hkg1
Connection: keep-alive

{"status":"ready","redis":true}

$ curl -i -X POST <URL>/ask -H "Content-Type: application/json" -d '{"question":"Hello"}'
HTTP/1.1 401 Unauthorized
Content-Type: application/json
Date: Tue, 29 Sep 2026 16:34:24 GMT
Server: railway-hikari
x-railway-request-id: YwrtqR7TQsuw9MP_CYBc-A
Content-Length: 39
x-hikari-trace: hkg1.aebn
x-railway-edge: hkg1
Connection: keep-alive

{"detail":"invalid or missing API key"}

$ curl -i -X POST <URL>/ask -H "Content-Type: application/json" -H "X-API-Key: $AGENT_API_KEY" -H "X-User-Id: sv-test" -d '{"question":"Deploy là gì?"}'
HTTP/1.1 200 OK
Content-Type: application/json
Date: Tue, 29 Sep 2026 16:34:24 GMT
Server: railway-hikari
x-railway-request-id: DUFx99FjTNaCQEG3WUN5dQ
Content-Length: 279
x-hikari-trace: hkg1.aebn
x-railway-edge: hkg1
vary: accept-encoding
Connection: keep-alive

{"answer":"Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud.","user_id":"sv-test","history_length":0,"cost_usd":2.145e-05,"tokens":{"in":3,"out":35}}

$ for i in $(seq 1 15); do curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask ... -H "X-User-Id: sv-test" -d '{"question":"test"}'; done; echo
200 200 200 200 200 200 200 200 200 429 429 429 429 429 429
```

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl
