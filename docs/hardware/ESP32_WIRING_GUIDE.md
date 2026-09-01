# Hướng Dẫn Đấu Nối Phần Cứng & Nạp Firmware ESP32

Tài liệu hướng dẫn chi tiết sơ đồ chân, nguyên lý mạch điện và cách nạp Firmware cho thiết bị **Kiosk Cấp Giấy Vệ Sinh Thông Minh (Smart Toilet Paper Dispenser)**.

---

## 🛠️ 1. Danh Sách Linh Kiện Cần Chuẩn Bị (BOM)

| STT | Linh kiện | Thông số khuyến nghị | Chức năng |
| :--- | :--- | :--- | :--- |
| 1 | **Bo mạch ESP32** | ESP32-WROOM-32 (30 hoặc 38 chân) | Vi điều khiển trung tâm + WebServer / WebSocket |
| 2 | **Động cơ Motor DC** | 12V DC kèm hộp giảm tốc (50 - 150 RPM) | Kéo trục nhả cuộn giấy vệ sinh |
| 3 | **Mạch công suất Motor Driver** | TB6612FNG hoặc L298N (2A - 5A) | Điều khiển chiều và băm xung PWM tốc độ motor |
| 4 | **Cảm biến Encoder** | Rotary Encoder quang học (10 - 20 xung/vòng) | Đếm vòng quay trục giấy đo chính xác số cm |
| 5 | **Cảm biến hết giấy** | Cảm biến quang hồng ngoại IR hoặc công tắc hành trình | Phát hiện khi cuộn giấy hết |
| 6 | **Nguồn cấp (Power Supply)** | Nguồn Adapter 12V - 2A DC | Cấp nguồn motor và hạ áp cho ESP32 |
| 7 | **Mạch hạ áp (Buck Converter)** | LM2596 hoặc MP1584 (Hạ 12V $\rightarrow$ 5V) | Cấp nguồn 5V ổn định cho ESP32 và cảm biến |

---

## 🔌 2. Bảng Sơ Đồ Chân Đấu Nối (Pinout Map)

### A. Kết nối ESP32 với Mạch Driver Motor (TB6612FNG / L298N)
| Chân ESP32 | Chân Mạch Driver | Mô tả chức năng |
| :--- | :--- | :--- |
| **GPIO 18** | **PWM / ENA** | Tín hiệu PWM băm xung điều chỉnh tốc độ motor (0 - 255) |
| **GPIO 19** | **IN1** | Điều khiển chiều quay thuận (nhả giấy ra) |
| **GPIO 21** | **IN2** | Điều khiển chiều quay nghịch / thắng động cơ |
| **GND** | **GND** | Nối Mass chung (Common Ground) |
| **VIN (hoặc 5V ngoài)**| **VCC** | Nguồn nuôi logic 5V cho IC driver |
| **Nguồn 12V ngoài** | **VM / 12V** | Nguồn công suất cấp cho động cơ |

---

### B. Kết nối ESP32 với Cảm Biến Encoder & Cảm Biến Hết Giấy
| Chân ESP32 | Chân Cảm biến | Mô tả chức năng |
| :--- | :--- | :--- |
| **GPIO 34** | **Encoder Kênh A (Signal)** | Tín hiệu xung ngắt ngoài (ISR đếm vòng quay) |
| **GPIO 35** | **Encoder Kênh B (tùy chọn)** | Đo hướng quay (nếu dùng encoder 2 pha A/B) |
| **GPIO 32** | **Paper Sensor (OUT)** | Tín hiệu phát hiện hết giấy (LOW = Có giấy, HIGH = Hết giấy) |
| **3.3V hoặc 5V** | **VCC** | Nguồn nuôi cảm biến |
| **GND** | **GND** | Mass chung |

---

## ⚡ 3. Sơ Đồ Nguyên Lý Nguồn Điện (Power Architecture)

```text
    ┌───────────────────────────┐
    │  Adapter Nguồn 12V - 2A   │
    └─────────────┬─────────────┘
                  │
        ┌─────────┴───────────────┐
        │                         │ (12V công suất)
        ▼                         ▼
 ┌───────────────┐        ┌───────────────┐
 │ Mạch Hạ Áp    │        │ Mạch Driver   │──────► [ Motor DC 12V ]
 │ LM2596 (12V-5V)│        │ TB6612 / L298 │
 └──────┬────────┘        └───────▲───────┘
        │ (5V)                    │ (GPIO 18, 19, 21)
        ▼                         │
 ┌───────────────┐                │
 │  ESP32 Board  │────────────────┘
 └──────┬────────┘
        │ (GPIO 34, 32)
        ▼
 [ Encoder & Cảm biến hết giấy ]
```

> ⚠️ **LƯU Ý QUAN TRỌNG:**
> - **Luôn nối chung dây Mass (GND)** giữa nguồn 12V, mạch hạ áp và bo ESP32 để tín hiệu PWM và ngắt Encoder không bị nhiễu.
> - **Lắp tụ 100nF** song song với 2 cực động cơ DC để triệt tiêu tia lửa điện và xung gai điện áp làm reset ESP32.

---

## 💻 4. Hướng Dẫn Cài Đặt & Nạp Code bằng Arduino IDE

### Bước 1: Cài đặt thư viện cần thiết
Mở Arduino IDE $\rightarrow$ **Tools** $\rightarrow$ **Manage Libraries...** và tìm cài đặt các thư viện sau:
1. `ESPAsyncWebServer` (bởi me-no-dev hoặc lacamera)
2. `AsyncTCP` (bởi me-no-dev hoặc dvarrel)
3. `ArduinoJson` (phiên bản 6.x hoặc 7.x)

### Bước 2: Cấu hình thông tin Wi-Fi
Trong file `esp32_smart_toilet.ino`, chỉnh sửa tên và mật khẩu Wi-Fi của phòng vệ sinh / tòa nhà:
```cpp
const char* WIFI_SSID = "Tên_WiFi_Của_Bạn";
const char* WIFI_PASS = "Mat_Khau_WiFi";
```
*(Nếu không có Wi-Fi, ESP32 sẽ tự động phát sóng AP tên `SmartToilet-AP` với IP `192.168.4.1`)*.

### Bước 3: Nạp Code vào ESP32
1. Chọn Board: **Tools** $\rightarrow$ **Board** $\rightarrow$ **ESP32 Arduino** $\rightarrow$ **ESP32 Dev Module**.
2. Chọn Port: Cổng COM tương ứng của ESP32.
3. Nhấn nút **Upload** (Mũi tên sang phải).

---

## 📡 5. Kiểm Tra API Trực Tiếp (Testing API)

Sau khi ESP32 khởi động và hiển thị IP (ví dụ: `192.168.1.150` hoặc `192.168.4.1`):

1. **Kiểm tra trạng thái (Health Check)**:
   ```bash
   curl http://192.168.1.150/health
   ```
   *Kết quả:*
   ```json
   {"status":"ok","device":"ESP32_SMART_TOILET","uptime_sec":42,"paper_sensor":"READY","state":"idle"}
   ```

2. **Lệnh cấp 70 cm giấy**:
   ```bash
   curl -X POST http://192.168.1.150/dispense -H "Content-Type: application/json" -d "{\"length_cm\": 70}"
   ```

3. **Lệnh dừng khẩn cấp**:
   ```bash
   curl -X POST http://192.168.1.150/stop
   ```
