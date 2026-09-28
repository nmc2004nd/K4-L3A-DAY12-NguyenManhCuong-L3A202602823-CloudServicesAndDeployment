# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Dưới đây là Dockerfile "chạy được nhưng chưa production": một stage,
# chạy bằng user root, không có health check, base image nặng.
#
# NHIỆM VỤ: sửa file này thành bản production-ready. Yêu cầu:
#   [ ] Multi-stage build: stage `builder` cài dependency, stage runtime
#       chỉ copy kết quả sang → image nhỏ hơn, không mang theo compiler.
#       Cú pháp: `FROM python:3.11-slim AS builder`
#   [ ] Base image slim (hoặc alpine), không dùng `python:3.11` bản đầy đủ
#   [ ] COPY requirements.txt và pip install TRƯỚC khi COPY source code
#       (Docker cache theo layer: sửa 1 dòng code không phải cài lại thư viện)
#   [ ] Tạo user thường và chuyển sang bằng lệnh `USER` — container chạy
#       root nghĩa là ai thoát được khỏi app cũng thành root trên host
#   [ ] Có `HEALTHCHECK` gọi vào endpoint /health
#   [ ] Đọc cổng từ biến môi trường PORT (cloud tự gán cổng, không cố định 8000)
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# FROM python:3.11

# WORKDIR /app

# COPY . .

# RUN pip install -r requirements.txt

# EXPOSE 8000

# CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]


# ==========================================
# Stage 1: Builder (Cài đặt dependencies)
# ==========================================
FROM python:3.11-slim AS builder

WORKDIR /app

# Thiết lập môi trường để pip không ghi file cache thừa (.cache)
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# 1. Tối ưu Layer Caching: COPY requirements.txt và cài đặt thư viện trước
COPY requirements.txt .

# Cài đặt thư viện vào thư mục /install để copy sang Stage runtime
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ==========================================
# Stage 2: Runtime (Image chính thức gọn nhẹ)
# ==========================================
FROM python:3.11-slim AS runtime

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PORT=8000

# 2. Cài đặt curl phục vụ HEALTHCHECK
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# 3. Tạo user thường (non-root) để tăng cường bảo mật
RUN addgroup --system appgroup && adduser --system --group appuser

# 4. Copy các gói thư viện đã build từ stage builder sang runtime
COPY --from=builder /install /usr/local

# 5. Copy toàn bộ source code ứng dụng và cấp quyền cho appuser
COPY . .
RUN chown -R appuser:appgroup /app

# 6. Chuyển sang quyền user thường (không chạy dưới root)
USER appuser

EXPOSE ${PORT}

# 7. Xóa bỏ ENTRYPOINT kế thừa từ base image nếu có
ENTRYPOINT []

# 8. HEALTHCHECK gọi vào endpoint /health
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# 9. Chạy uvicorn nhận cổng động từ biến môi trường PORT
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
