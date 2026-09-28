"""CP3 — Xác thực bằng API key.

Public URL = ai cũng gọi được. Không có lớp này, hóa đơn LLM của bạn do
người lạ quyết định.
"""

from __future__ import annotations

import secrets

from fastapi import Header, HTTPException, status

from .config import get_settings

ANONYMOUS_USER = "anonymous"


def verify_api_key(
    x_api_key: str | None = Header(default=None),
    x_user_id: str | None = Header(default=None),
) -> str:
    """Kiểm tra header `X-API-Key` và trả về `user_id` nếu hợp lệ.

    Thực hiện xác thực API Key theo các bước:
      1. Đọc khóa chính xác từ `get_settings().agent_api_key`.
      2. Nếu thiếu `x_api_key` hoặc khóa không chính xác:
         Báo lỗi `HTTPException(status_code=401, detail="invalid or missing API key")`.
      3. So sánh `x_api_key` và khóa cấu hình bằng `secrets.compare_digest(a, b)`
         để đảm bảo thời gian xử lý đồng nhất (constant-time), phòng chống tấn công rò rỉ
         thời gian (timing attack). Không dùng toán tử `==`.
      4. Khi hợp lệ, trả về `x_user_id` nếu client có truyền (và không rỗng),
         ngược lại trả về giá trị mặc định `ANONYMOUS_USER` ("anonymous").
    """
    settings = get_settings()
    expected_api_key = settings.agent_api_key

    # Kiểm tra sự tồn tại của header X-API-Key
    if x_api_key is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid or missing API key",
        )

    # So sánh an toàn chống timing attack
    if not secrets.compare_digest(x_api_key, expected_api_key):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid or missing API key",
        )

    # Trả về ID định danh người dùng
    if x_user_id and x_user_id.strip():
        return x_user_id

    return ANONYMOUS_USER