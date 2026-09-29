# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder của mỗi câu bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Phạm Thanh Sơn  Mã học viên: 2A202602794

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Khi deploy lên Railway, lần đầu các biến môi trường chưa được áp dụng: log cho thấy container chỉ nhận được `{'port': '8080'}`. Lúc đó app vẫn khởi động, `/health` trả 200 nên Railway coi bản deploy là khỏe, nhưng mọi request `/ask` và `/ready` đều 500. Nếu `agent_api_key` có mặc định `"changeme"` thì còn tệ hơn: app chạy công khai với một khóa ai cũng đoán được, người lạ gọi `/ask` thoải mái và tiêu tiền LLM của mình mà không có lỗi nào báo. Vì vậy mình sửa thêm để `get_settings()` được gọi ngay trong `lifespan`: thiếu key thì process chết lúc khởi động (`Application startup failed. Exiting.`), healthcheck fail và platform không đưa bản lỗi lên.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Một dòng log thật khi gọi `/ask`:
> `{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T15:03:37.032505+00:00", "user_id": "sv01", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}`
>
> Hai việc làm được mà `print("đã trả lời xong")` không làm được: (1) lọc/tổng hợp theo field, ví dụ cộng `cost_usd` theo `user_id` để biết ai tiêu nhiều tiền nhất trong ngày; (2) đặt cảnh báo trên hệ thống log, ví dụ báo động khi số event `level=error` tăng đột biến hoặc `tokens_in` vượt ngưỡng. Vì mỗi event nằm trên một dòng JSON nên Railway/Datadog parse được trực tiếp.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1730 MB (1.73GB) |
| Multi-stage | 310 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Số đo thật (`docker images`): `agent:single` 1.73GB, `day12-agent:prod` 310MB — giảm khoảng 1.4GB. Phần chênh lệch chủ yếu là base image `python:3.11` bản đầy đủ (Debian đầy đủ kèm gcc, header, git, nhiều thư viện hệ thống để build extension), cộng với mọi thứ bị `COPY . .` kéo vào (`.venv` local, `.git`, tests...) và cache pip. Bản multi-stage chạy trên `python:3.11-slim`, chỉ copy `/opt/venv` đã cài xong cùng `app/` và `utils/`; `.dockerignore` loại `.venv`, `.git`, `.env`, tests.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Mình sửa một ký tự trong `app/main.py` rồi build lại với `--progress=plain`. Các bước `COPY requirements.txt`, `RUN python -m venv`, `RUN pip install`, `groupadd/useradd`, `WORKDIR` và `COPY --from=builder /opt/venv` đều báo `CACHED`; chỉ `COPY app/` và `COPY utils/` chạy lại, build mất chưa tới 1 giây. Nếu đặt `COPY . .` trước `RUN pip install` thì bất kỳ thay đổi code nào cũng làm layer COPY đổi hash, kéo theo mọi layer phía sau (kể cả `pip install`) bị vô hiệu cache, nên mỗi lần sửa code là cài lại toàn bộ thư viện.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: code Python có lỗ hổng (ví dụ deserialize dữ liệu không tin cậy, path traversal, hoặc thư viện có RCE) → kẻ tấn công chạy được lệnh trong container → nếu process là root thì họ đọc/ghi được mọi file trong container, cài thêm công cụ, và nếu container có mount volume/docker socket hoặc kernel có lỗ hổng escape thì root trong container dễ thành root trên host. Lệnh `USER app` cắt chuỗi ở bước thứ hai: shell chiếm được chỉ là user `app` (uid 999, mình kiểm tra bằng `docker compose exec agent id`), không cài được package, không ghi được vào thư mục hệ thống, và thoát ra host cũng chỉ với quyền thấp.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request trong 2 giây**. Cách đạt: gửi 10 request lúc 10:00:59 (hết quota của phút 10:00), sang 10:01:00 bộ đếm reset, gửi tiếp 10 request lúc 10:01:00–10:01:01. Với sliding window, lúc 10:01:01 hệ thống nhìn lại 60 giây gần nhất vẫn thấy 10 request trước đó nên request thứ 11 bị 429 ngay.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit giới hạn **số lượng request theo thời gian** (10 request/60 giây), cost guard giới hạn **số tiền cộng dồn theo tháng** (10 USD/user/tháng).
> - Rate limit cho qua nhưng cost guard chặn: user gửi đều 5 request/phút nhưng mỗi câu hỏi rất dài, lịch sử hội thoại lớn → mỗi lần tốn nhiều token; sau vài ngày tổng chi phí vượt 10 USD → 402.
> - Rate limit chặn nhưng cost guard cho qua: một script gửi 15 request "hi" trong 1 giây, mỗi request gần như không tốn tiền → từ request thứ 11 bị 429 dù ngân sách còn nguyên.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> 1. Redis mất kết nối → endpoint gộp của cả 3 container cùng trả 503.
> 2. Liveness probe của orchestrator fail liên tiếp vài lần → nó kết luận cả 3 container "chết" và restart chúng.
> 3. Trong lúc restart, không còn container nào nhận request → toàn bộ service down, request đang xử lý dở bị cắt.
> 4. Container khởi động lại nhưng Redis vẫn chưa về → probe lại fail → restart tiếp, rơi vào vòng lặp restart.
> 5. Redis trở lại sau 30 giây, các container mới ổn định dần.
>
> Tách ra thì Redis chết chỉ làm `/ready` = 503 → load balancer tạm ngừng gửi traffic, còn `/health` vẫn 200 nên không container nào bị restart; Redis về là `/ready` = 200 và traffic quay lại ngay.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Mình chưa chạy được `--scale agent=3` vì compose đang map cố định cổng `8000:8000` (3 bản sao không thể cùng chiếm một cổng host; muốn scale cần bỏ `ports` và đặt nginx phía trước). Thay vào đó mình kiểm chứng tính stateless bằng cách restart container: gọi `/ask` 2 lần với `X-User-Id: sv01` thấy `history_length` = 0 rồi 2, sau `docker compose restart agent` gọi tiếp thì `history_length` = 4, nghĩa là lịch sử nằm trong Redis chứ không nằm trong process. Nếu lưu trong dict Python thì với 3 instance, `history_length` sẽ nhảy lung tung tùy request rơi vào instance nào (ví dụ 0, 0, 2, 0, 2...) và về 0 mỗi khi container restart.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi mình gặp khi deploy Railway:
> - **Triệu chứng 1:** `/health` trả `502 Application failed to respond`. Xem Deploy Logs thấy `Uvicorn running on http://0.0.0.0:8080`, trong khi domain đang trỏ vào Port 8000. Nguyên nhân: Railway tự set `PORT=8080`, Dockerfile đọc `${PORT:-8000}` nên app nghe 8080. Sửa: đổi port của domain trong Settings → Networking thành 8080. (Trước đó mình cũng bỏ `startCommand` trong `railway.toml` để dùng CMD `sh -c` của Dockerfile, đảm bảo `$PORT` được shell nội suy.)
> - **Triệu chứng 2:** `/health` 200 nhưng `/ready` và `/ask` đều 500. Traceback trong Deploy Logs: `agent_api_key Field required [type=missing, input_value={'port': '8080'}]` → container không nhận được biến nào ngoài PORT vì bản deploy đang chạy được tạo trước khi thêm Variables. Sửa: redeploy sau khi apply biến, và thêm `get_settings()` vào `lifespan` để lần sau thiếu secret thì app chết ngay lúc khởi động thay vì báo khỏe giả.
