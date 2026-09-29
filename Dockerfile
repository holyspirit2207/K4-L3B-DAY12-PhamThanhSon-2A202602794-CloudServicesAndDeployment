# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
#   Stage 1 `builder`: cài dependency vào một virtualenv riêng (/opt/venv).
#   Stage 2 `runtime`: chỉ copy virtualenv + source sang image slim sạch,
#                      chạy bằng user thường, có HEALTHCHECK, đọc $PORT.
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder ────────────────────────────────────────────────
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Chỉ copy requirements.txt trước: layer pip install được cache cho tới khi
# danh sách thư viện đổi, sửa code không làm cài lại dependency.
COPY requirements.txt .
RUN pip install -r requirements.txt

# ── Stage 2: runtime ────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8000

# User thường, không có quyền root trong container
RUN groupadd --system app && useradd --system --gid app --no-create-home app

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=app:app app/ ./app/
COPY --chown=app:app utils/ ./utils/

USER app

EXPOSE 8000

# Image slim không có curl → dùng chính Python để gọi /health
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen(f'http://127.0.0.1:{os.environ.get(\"PORT\", \"8000\")}/health', timeout=3)" || exit 1

# Shell form để nội suy ${PORT}; `exec` để uvicorn là PID 1 và nhận SIGTERM trực tiếp
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
