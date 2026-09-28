# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay từng dòng trả lời mẫu bên dưới bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Mạnh Cường  Mã học viên: 2A202602823

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Theo mình, tình huống nguy hiểm nhất là deploy lên cloud nhưng quên set
> `AGENT_API_KEY`. Nếu app dùng mặc định `"changeme"` thì nó vẫn báo healthy,
> trong khi người ngoài có thể đoán được key và gọi `/ask`, làm tốn ngân sách.
> Khi không có giá trị mặc định, app dừng ngay lúc khởi động và Railway báo
> deployment lỗi. Nhờ vậy mình biết phải sửa biến môi trường trước khi public
> service, thay vì phát hiện sau khi đã có request lạ.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Một dòng mình lấy từ log của bản deploy là:
>
> ```json
> {"event":"ask_completed","level":"info","timestamp":"2026-09-28T10:08:55.723021+00:00","user_id":"sv-test","tokens_in":3,"tokens_out":35,"cost_usd":0.00002145}
> ```
>
> Với log này mình có thể lọc theo `event`, `user_id` hoặc khoảng thời gian để
> tìm đúng request cần kiểm tra. Mình cũng có thể cộng `tokens_in`,
> `tokens_out`, `cost_usd` để làm thống kê hoặc đặt cảnh báo chi phí. Một câu
> `print("đã trả lời xong")` không có các trường rõ ràng nên máy rất khó lọc và
> tổng hợp tự động.

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
| 1 stage (bản đầu) | 1.7 GB |
| Multi-stage | 291 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Mình build lại hai bản trên cùng máy và lấy số từ `docker images`. Bản
> 1-stage dùng image `python:3.11` đầy đủ, đồng thời giữ mọi thành phần dùng
> trong quá trình cài đặt. Bản multi-stage dùng `python:3.11-slim`; stage
> builder chỉ dùng để cài package, còn image chạy thật chỉ nhận các package đã
> cài và source code. Vì vậy các thành phần hệ điều hành và công cụ build không
> cần lúc runtime không đi vào image cuối, làm dung lượng giảm khoảng 1.4 GB.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Với Dockerfile hiện tại, sửa `app/main.py` không làm thay đổi
> `requirements.txt`, nên các layer base image, cài `curl`, tạo user và cài
> dependency trong builder vẫn lấy từ cache. Docker phải chạy lại `COPY . .`
> ở runtime và layer `chown` ngay sau nó; các lệnh metadata phía sau chạy lại
> rất nhanh. Nếu đặt `COPY . .` trước `RUN pip install`, chỉ cần sửa một ký tự
> trong source thì checksum của layer copy đã đổi, kéo theo layer cài package
> bị mất cache và phải tải/cài toàn bộ dependency lại.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi xấu nhất mình hình dung là: code Python có lỗi cho phép thực thi lệnh,
> kẻ tấn công lấy được shell trong container, process lại đang là root nên họ
> có thể sửa file hệ thống hoặc đọc các tài nguyên nhạy cảm được mount vào
> container. Nếu container còn được cấp quyền cao, mount Docker socket hoặc có
> lỗ hổng container escape, quyền root đó có thể bị dùng để chiếm quyền cao trên
> host. `USER appuser` cắt chuỗi ở bước sau khi vào được container: lệnh bị
> chiếm quyền chỉ chạy với user thường, không tự có quyền sửa hệ thống. Cách này
> giảm thiệt hại chứ không thay thế việc vá lỗ hổng và cấu hình container an
> toàn.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Người dùng có thể gửi tối đa 20 request trong 2 giây. Họ gửi 10 request ở
> cuối phút cũ, ví dụ từ `12:00:59`, rồi gửi tiếp 10 request ngay khi bộ đếm
> reset ở `12:01:00`. Cả hai nhóm đều hợp lệ với fixed window 10 request/phút
> nhưng thực tế nằm sát nhau. Sliding window nhìn lại đúng 60 giây nên không có
> khe hở ở ranh giới phút như vậy.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit giới hạn tốc độ gọi trong một khoảng thời gian ngắn, còn cost
> guard giới hạn tổng tiền một user đã dùng trong cả tháng. Ví dụ một user gọi
> đều một request mỗi phút thì không vượt rate limit, nhưng nếu mỗi request đắt
> thì cuối cùng vẫn chạm ngân sách và bị cost guard trả 402. Ngược lại, một
> user còn nguyên ngân sách nhưng bắn 15 request rất rẻ trong vài giây thì cost
> guard vẫn cho qua về mặt chi phí, còn rate limit phải chặn các request sau
> bằng 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Nếu gộp hai endpoint và cho liveness kiểm tra Redis thì khi Redis mất kết nối,
> cả 3 container cùng trả health check lỗi. Platform nghĩ process của cả 3 đã
> chết nên lần lượt restart chúng. Container mới lên vẫn gặp đúng Redis đang
> lỗi, lại fail health check và tiếp tục rơi vào vòng restart, trong lúc đó cụm
> gần như không còn instance ổn định để phục vụ. Tách riêng thì `/health` vẫn
> 200 vì process còn sống, còn `/ready` trả 503 để load balancer tạm ngừng gửi
> traffic. Khi Redis trở lại, các instance tự ready lại mà không cần restart
> hàng loạt.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Khi dùng Redis chung, request vào instance nào cũng đọc được cùng một lịch
> sử, nên `history_length` tăng đều theo số message đã lưu, thường là
> `0, 2, 4, 6...` vì mỗi lượt thêm một message user và một message assistant.
> Nếu dùng dict Python thì mỗi container có một bản lịch sử riêng. Khi load
> balancer chia request qua 3 container, mình có thể thấy kiểu `0, 0, 2, 0,
> 2...` tùy request rơi vào đâu, thay vì một dãy tăng liên tục. Restart một
> container còn làm phần lịch sử trong dict của nó mất hẳn.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi mình gặp lúc bắt đầu deploy là `railway status` báo service đã link
> trước đó không còn tồn tại trong project: `not found in project, run railway
> service to relink`. Mình chạy `railway service list --json` và thấy project
> chỉ còn Redis Online, nên xác định đây không phải lỗi code hay Dockerfile mà
> là liên kết service cũ. Mình tạo lại service `day12-agent`, chạy
> `railway service link day12-agent`, set `AGENT_API_KEY`, tham chiếu
> `REDIS_URL` của Redis rồi deploy lại. Sau đó trạng thái chuyển sang SUCCESS,
> `/health` và `/ready` đều trả 200. Khi thử `/ask` mình còn gặp 401 vì terminal
> chưa nạp `$AGENT_API_KEY`; chạy `set -a; source .env; set +a` rồi gọi lại thì
> nhận 200.
