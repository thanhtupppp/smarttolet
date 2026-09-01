# Thiết Kế Chi Tiết: Ứng Dụng Kiosk Cấp Giấy Vệ Sinh Thông Minh (Smart Toilet Paper Control App)

## 1. Giới Thiệu & Mục Tiêu Hệ Thống

Ứng dụng **Smart Toilet Kiosk** được xây dựng trên nền tảng **Flutter** nhằm giải quyết bài toán chống lãng phí và thất thoát giấy vệ sinh tại các khu vực công cộng. Thiết bị điện thoại/tablet đóng vai trò là trạm điều khiển Kiosk thông minh (gồm camera trước + màn hình hiển thị + bộ não nhận diện AI offline), giao tiếp với bo mạch điều khiển cơ khí **ESP32**.

---

## 2. Kiến Trúc Tổng Thể

```text
┌──────────────────────────────────────────────────────────┐
│                   📱 FLUTTER KIOSK APP                   │
├──────────────────────────────────────────────────────────┤
│ 1. KIOSK UI LAYER                                        │
│    ├── Màn hình Kiosk Người dùng (4 Trạng thái động)      │
│    │     ├── Trạng thái Chờ (Idle / Radar Scan)          │
│    │     ├── Nhận diện Khuôn mặt (Face Lock & Analyze)   │
│    │     ├── Đang Cấp Giấy (Dispense Progress Animation)  │
│    │     └── Cooldown Active (Đếm ngược thời gian chờ)   │
│    └── Màn hình Quản trị Admin (Bảo vệ bằng PIN Code)    │
│          ├── Cài đặt Độ dài giấy (50 - 150 cm)           │
│          ├── Cài đặt Thời gian Cooldown (1 - 60 phút)    │
│          ├── Chọn Mode Kết nối (Demo / HTTP / WS / MQTT) │
│          ├── Hiệu chuẩn Motor & Test Cảm biến            │
│          └── Thống kê & Lịch sử lượt sử dụng             │
├──────────────────────────────────────────────────────────┤
│ 2. CORE & AI LOGIC LAYER                                 │
│    ├── Camera & ML Kit Face Detection                    │
│    ├── TFLite MobileFaceNet (192-d Face Embeddings)      │
│    ├── Cosine Similarity Matcher                         │
│    └── Cooldown Manager (Tự động xóa vector sau Cooldown)│
├──────────────────────────────────────────────────────────┤
│ 3. DISPENSER DRIVER LAYER                                │
│    ├── MockDemoDriver (Chạy giả lập không cần phần cứng) │
│    ├── HttpRestDriver (POST /dispense đến ESP32)         │
│    ├── WebSocketDriver (Nhận % realtime từ ESP32)        │
│    └── MqttDriver (Pub/Sub qua MQTT Broker)              │
└─────────────────────────────┬────────────────────────────┘
                              │ WiFi / LAN / AP
                              ▼
┌──────────────────────────────────────────────────────────┐
│                      🤖 ESP32 FIRMWARE                   │
│  - WiFi AP/STA Mode, HTTP REST Server, WebSocket Server  │
│  - PWM Motor DC Controller + Encoder Counter (Pulse)     │
│  - Cảm biến giấy (IR Paper Sensor) & Kẹt motor           │
└──────────────────────────────────────────────────────────┘
```

---

## 3. Thiết Kế Chi Tiết Các Màn Hình

### 3.1. Màn hình Kiosk Người dùng (`KioskHomeScreen`)
* **Chế độ Kiosk Toàn màn hình**: Ẩn Navigation Bar và Status Bar, vô hiệu hóa các thao tác chạm thông thường trên màn hình camera.
* **Khu vực Camera**: Tỉ lệ khung hình tối ưu, có lớp phủ (Overlay) đồ họa hiển thị ô nhận diện khuôn mặt và sóng quét radar.
* **4 Trạng thái chuyển động (State Transitions)**:
  1. `Idle`: Mời người dùng nhìn vào camera.
  2. `Scanning`: Khi phát hiện khuôn mặt, đổi màu viền xanh neon, tính toán vector đặc trưng.
  3. `Dispensing`: Hiển thị cuộn giấy 3D/vector xoay, thanh tiến trình % và cm giấy đang nhả.
  4. `Cooldown`: Hiển thị đồng hồ đếm ngược vòng tròn với số phút:giây còn lại.

### 3.2. Cơ chế Mở khóa Quản trị Admin
* **Nút ẩn**: Biểu tượng ⚙️ nhỏ ở góc trên bên phải màn hình.
* **Kích hoạt**: Nhấn giữ liên tục 3 giây (kèm hiệu ứng vòng sáng nạp đầy).
* **Bảo mật PIN**: Bàn phím số dạng dial pad với mã PIN mặc định `1234` (có thể đổi trong cài đặt), khóa tạm thời 30 giây nếu nhập sai quá 5 lần.

### 3.3. Màn hình Cài đặt Admin (`AdminSettingsScreen`)
* **Cấu hình Cấp giấy**:
  * Độ dài cấp mặc định: Slider/Number Picker (50cm – 150cm, mặc định 70cm).
  * Thời gian Cooldown: Slider (1 phút – 60 phút, mặc định 9 phút).
* **Cấu hình Kết nối ESP32**:
  * Chế độ kết nối: `Demo Mode` (mặc định), `HTTP REST API`, `WebSocket`, `MQTT`.
  * Địa chỉ IP / Port / URL ESP32: ví dụ `http://192.168.4.1/dispense` hoặc `ws://192.168.4.1/ws`.
  * Nút `Kiểm tra kết nối` (Ping / Test Dispense).
* **Hiệu chuẩn Motor & Cảm biến**:
  * Nhập tỉ lệ xung encoder / cm (Pulse per cm).
  * Nút Test nhả 10cm để đo kiểm thủ công.
* **Bảng Thống kê (Statistics Dashboard)**:
  * Tổng số lượt cấp giấy hôm nay / tuần này.
  * Tổng mét giấy đã cấp & Ước tính phần trăm giấy còn lại trong cuộn.
  * Nhật ký sự kiện (Logs).

---

## 4. Quản Lý Quyền Riêng Tư (Privacy-First Data Architecture)

* **Không lưu trữ ảnh**: Ảnh chụp từ camera chỉ đưa vào bộ đệm RAM để nhận diện và bị hủy ngay lập tức sau khi trích xuất vector.
* **Dữ liệu Vector tạm thời**: Vector đặc trưng (192 số float) chỉ được lưu trong bộ nhớ tạm cùng mốc thời gian `timestamp`.
* **Cơ chế Tự hủy (Auto-Purge)**: Sau khi thời gian Cooldown kết thúc (ví dụ 9 phút), vector đó sẽ tự động bị xóa hoàn toàn khỏi bộ nhớ, không để lại bất kỳ dữ liệu định danh nào.

---

## 5. Kế Hoạch Triển Khai

1. **Khởi tạo dự án Flutter Kiosk App** trong thư mục `d:\smarttolet`.
2. **Xây dựng Hệ thống Design System & Theme**: Màu sắc hiện đại (Dark Kiosk Theme với điểm nhấn Cyan/Neon Blue/Emerald Green), typography rõ nét, responsive cho cả điện thoại dọc và máy tính bảng.
3. **Xây dựng Màn hình Kiosk Người dùng (User Kiosk Screen)** đầy đủ 4 trạng thái tương tác sống động cùng hiệu ứng hoạt họa cấp giấy.
4. **Xây dựng Màn hình Xác thực PIN & Bảng Điều Khiển Admin (Admin Settings)**.
5. **Tích hợp DispenserService đa năng** (Demo Mock Driver + HTTP REST Driver + WebSocket Driver).
6. **Kiểm thử và hoàn thiện toàn bộ giao diện**.
