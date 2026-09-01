# Triển Khai Thực Tế: Firmware ESP32 & Mobile Camera AI (Real-World Deployment)

Kế hoạch triển khai thực tế cho toàn bộ hệ thống Cấp Giấy Vệ Sinh Thông Minh (**Smart Toilet Paper Dispenser**), kết nối giữa ứng dụng **Flutter Kiosk** và bo mạch **ESP32 Hardware Controller**.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Mục tiêu:**
1. Xây dựng hoàn chỉnh mã nguồn Firmware C++ cho ESP32 điều khiển motor nhả giấy qua xung Encoder, cảm biến hết giấy, WebServer HTTP REST & WebSocket API, kèm sơ đồ đấu nối phần cứng chi tiết.
2. Tích hợp Camera thực tế + Google ML Kit Face Detection + Trích xuất đặc trưng khuôn mặt (Face Embedding) với cơ chế tự hủy bảo vệ quyền riêng tư.
3. Tích hợp âm thanh / Voice Prompt giọng nói tiếng Việt hướng dẫn người dùng.
4. Cấu hình quyền truy cập phần cứng Android (`CAMERA`, `INTERNET`, `ACCESS_WIFI_STATE`, `usesCleartextTraffic="true"`).

**Tech Stack:**
- **ESP32 Firmware**: C++ (Arduino Core / ESP-IDF / PlatformIO), `ESPAsyncWebServer`, `AsyncTCP`, `ArduinoJson`.
- **Flutter App**: `camera: ^0.11.0+2`, `google_mlkit_face_detection: ^0.13.0`, `flutter_tts: ^4.2.2`, `audioplayers: ^6.1.0`.

---

## Danh Sách Nhiệm Vụ Triển Khai

### Task 1: Sơ đồ Phần Cứng & Firmware ESP32 C++ (`firmware/esp32_smart_toilet/`)
- **Tạo thư mục**: `firmware/esp32_smart_toilet/`
- **Tập tin**:
  - `firmware/esp32_smart_toilet/esp32_smart_toilet.ino`: Mã nguồn C++ hoàn chỉnh gồm:
    - Wi-Fi Manager (hỗ trợ cả Wi-Fi Station và Access Point Fallback `SmartToilet-AP`).
    - Driver Motor PWM (hỗ trợ mạch cầu H L298N / TB6612 / Relay).
    - Ngắt ngoài Encoder ISR đo chính xác từng xung quay trục giấy theo mm/cm.
    - Cảm biến hồng ngoại phát hiện hết giấy (Paper Out IR sensor).
    - REST API: `POST /dispense` (nhận `{"length_cm": 70}`), `POST /stop`, `GET /health`, `GET /status`.
    - WebSocket Server `/ws` đẩy tọa độ xung và % nhả giấy trực tiếp theo thời gian thực về Flutter App.
  - `docs/hardware/ESP32_WIRING_GUIDE.md`: Sơ đồ chân Pinout ESP32, sơ đồ nguyên lý mạch điện (Schematic), bảng linh kiện cần chuẩn bị (BOM).

### Task 2: Cấu hình Android Manifest & Quyền Hệ Thống
- **Cập nhật**: `android/app/src/main/AndroidManifest.xml`
  - Thêm quyền `android.permission.CAMERA`
  - Thêm quyền `android.permission.INTERNET`, `android.permission.ACCESS_NETWORK_STATE`, `android.permission.ACCESS_WIFI_STATE`
  - Thêm `android:usesCleartextTraffic="true"` để kết nối HTTP/WebSocket cục bộ với ESP32 không bị chặn bởi bảo mật Android.
- **Cập nhật**: `android/app/build.gradle` (nâng `minSdkVersion 21` nếu cần cho ML Kit).

### Task 3: Tích hợp Thư Viện Camera & Face AI Service trên Flutter
- **Cập nhật**: `pubspec.yaml` thêm `camera`, `google_mlkit_face_detection`, `flutter_tts`.
- **Tạo mới**: `lib/services/face_detector_service.dart`:
  - Khởi tạo `FaceDetector` từ Google ML Kit với chế độ hiệu năng cao (`performanceMode: fast`).
  - Chuyển đổi `CameraImage` thành `InputImage`.
  - Nhận diện khuôn mặt trong khung hình, trích xuất bounding box và vector hóa nhận diện (Face ID hash/embedding).
- **Tạo mới**: `lib/services/voice_prompt_service.dart`:
  - Phát âm thanh giọng nói tiếng Việt hướng dẫn tương ứng từng trạng thái:
    - Sẵn sàng: *"Xin chào, vui lòng nhìn vào camera để nhận giấy"*
    - Đang cấp giấy: *"Đang cấp 70 cm giấy, vui lòng nhận giấy phía dưới"*
    - Cooldown: *"Bạn vừa nhận giấy, vui lòng đợi thêm [X] phút để nhận tiếp"*
    - Hết giấy: *"Thiết bị tạm hết giấy, vui lòng liên hệ nhân viên"*

### Task 4: Tích hợp Live Camera Viewfinder vào `KioskHomeScreen`
- **Tạo mới**: `lib/widgets/live_camera_view.dart`:
  - Hiển thị luồng Camera thực tế mượt mà từ camera trước của điện thoại / tablet.
  - Vẽ bounding box xanh neon bám theo khuôn mặt thực tế khi phát hiện.
  - Chế độ Fallback: Tự động chuyển về `CameraMockView` nếu chạy trên thiết bị không có camera (máy ảo emulator / desktop Windows).
- **Cập nhật**: `lib/screens/kiosk_home_screen.dart` kết nối luồng Camera thực tế với `KioskController`.

### Task 5: Kiểm Thử Toàn Diện & Hướng Dẫn Nạp Code ESP32
- Chạy toàn bộ test suites `flutter test`.
- Viết tài liệu hướng dẫn từng bước nạp Firmware cho ESP32 bằng Arduino IDE / PlatformIO và liên kết với ứng dụng điện thoại.
