# Smart Toilet Kiosk UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng ứng dụng Kiosk Flutter hoàn chỉnh cho máy cấp giấy vệ sinh thông minh (Smart Toilet Paper Control App) với giao diện người dùng Kiosk 4 trạng thái, cơ chế mô phỏng Demo Mode + HTTP/WS Driver, và màn hình Quản trị Admin bảo vệ bằng PIN Code.

**Architecture:** Kiến trúc phân tầng rõ ràng (Domain Model & Repository -> Driver Layer cho phần cứng -> State Management Controller -> Kiosk UI & Admin Settings Widgets). Hệ thống hoàn toàn độc lập, có thể chạy và tương tác ngay ở chế độ Demo Mode.

**Tech Stack:** Flutter 3.x / Dart 3.x, Provider/ChangeNotifier, `shared_preferences`, `intl`, `http`, `web_socket_channel`.

## Global Constraints
- Target: Flutter Android / Desktop / Web responsive.
- Dark Kiosk Theme: Nền tối (`#0B0F19`), màu điểm nhấn Cyan/Neon Blue (`#00E5FF`), Emerald Green (`#00E676`), Amber Warning (`#FFD600`), Crimson Error (`#FF1744`).
- Mặc định: 70cm giấy, 9 phút Cooldown, Demo Mode kích hoạt sẵn.
- Bảo mật: Mã PIN mặc định `1234`, kích hoạt bằng cách giữ biểu tượng ẩn 3 giây.

---

### Task 1: Initialize Flutter Project Structure & Dependencies

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/theme/kiosk_theme.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces: `KioskTheme` styling tokens and colors.

- [ ] **Step 1: Write failing test for theme and initial app load**
- [ ] **Step 2: Initialize Flutter project or create pubspec with required dependencies**
- [ ] **Step 3: Implement `KioskTheme` with modern dark kiosk tokens**
- [ ] **Step 4: Run tests to verify setup**
- [ ] **Step 5: Commit**

---

### Task 2: Implement Domain Models & Settings Repository

**Files:**
- Create: `lib/models/dispenser_config.dart`
- Create: `lib/models/dispense_record.dart`
- Create: `lib/models/kiosk_state.dart`
- Create: `lib/services/settings_service.dart`
- Test: `test/models/models_test.dart`

**Interfaces:**
- Produces:
  - `DispenserConfig` (`int paperLengthCm`, `int cooldownMinutes`, `ConnectionMode connectionMode`, `String espIp`, `int pulsePerCm`, `String adminPin`)
  - `DispenseRecord` (`String id`, `DateTime timestamp`, `int lengthCm`, `bool isSuccess`)
  - `SettingsService` (`Future<DispenserConfig> loadConfig()`, `Future<void> saveConfig(...)`)

- [ ] **Step 1: Write failing test for DispenserConfig serialization and SettingsService**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement models and SettingsService using SharedPreferences**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**

---

### Task 3: Implement Hardware Driver Layer (Demo, HTTP REST, WebSocket)

**Files:**
- Create: `lib/drivers/dispenser_driver.dart`
- Create: `lib/drivers/mock_demo_driver.dart`
- Create: `lib/drivers/http_rest_driver.dart`
- Create: `lib/drivers/websocket_driver.dart`
- Test: `test/drivers/driver_test.dart`

**Interfaces:**
- Produces:
  - `abstract class DispenserDriver` with `Future<bool> dispense({required int lengthCm, required Function(double progress, int currentCm) onProgress})` and `Future<bool> checkHealth()`
  - `MockDemoDriver` for simulated paper rolling
  - `HttpRestDriver` and `WebSocketDriver`

- [ ] **Step 1: Write failing test for MockDemoDriver progress callbacks**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement DispenserDriver interface and drivers**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**

---

### Task 4: Implement Kiosk State Management Controller

**Files:**
- Create: `lib/controllers/kiosk_controller.dart`
- Test: `test/controllers/kiosk_controller_test.dart`

**Interfaces:**
- Produces:
  - `KioskController` extending `ChangeNotifier`
  - States: `KioskStatus.idle`, `KioskStatus.scanning`, `KioskStatus.dispensing`, `KioskStatus.success`, `KioskStatus.cooldown`
  - Methods: `triggerFaceDetected(String faceId)`, `cancelOrReset()`, `updateConfig(DispenserConfig config)`, `checkCooldown(String faceId)`

- [ ] **Step 1: Write failing test for KioskController state machine & cooldown logic**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement KioskController**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**

---

### Task 5: Implement Animated Kiosk UI Components

**Files:**
- Create: `lib/widgets/camera_mock_view.dart`
- Create: `lib/widgets/radar_scan_overlay.dart`
- Create: `lib/widgets/paper_dispense_animation.dart`
- Create: `lib/widgets/cooldown_timer_view.dart`
- Test: `test/widgets/component_test.dart`

**Interfaces:**
- Produces:
  - `CameraMockView`: Live video viewfinder mockup with dynamic face bounding box and scanline
  - `PaperDispenseAnimation`: Animated 3D/2D paper roll unspooling with percentage meter
  - `CooldownTimerView`: Radial progress timer with glowing countdown clock

- [ ] **Step 1: Write widget tests for animated components**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement animated components**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**

---

### Task 6: Implement Admin PIN Security & Unlock Mechanism

**Files:**
- Create: `lib/widgets/admin_pin_dialog.dart`
- Create: `lib/widgets/hidden_trigger_button.dart`
- Test: `test/widgets/admin_pin_test.dart`

**Interfaces:**
- Produces:
  - `HiddenTriggerButton`: 3-second long press circular progress indicator
  - `AdminPinDialog`: Custom numeric keypad dialer with lockout protection

- [ ] **Step 1: Write widget test for PIN verification and wrong attempt lockout**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement HiddenTriggerButton and AdminPinDialog**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**

---

### Task 7: Implement Admin Settings Dashboard

**Files:**
- Create: `lib/screens/admin_settings_screen.dart`
- Create: `lib/widgets/stats_summary_card.dart`
- Test: `test/screens/admin_settings_screen_test.dart`

**Interfaces:**
- Produces:
  - `AdminSettingsScreen`: Full settings suite (Length slider, Cooldown slider, Connection selector, IP input, Calibration tool, Usage statistics table, Clear history)

- [ ] **Step 1: Write widget test for AdminSettingsScreen update actions**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement AdminSettingsScreen and widgets**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**

---

### Task 8: Assemble Kiosk Main Screen & Full App Experience

**Files:**
- Create: `lib/screens/kiosk_home_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/screens/kiosk_home_screen_test.dart`

**Interfaces:**
- Produces:
  - Complete `KioskHomeScreen` integrating Camera Viewfinder, Overlay indicators, State transitions, Demo triggers, and Admin shortcut

- [ ] **Step 1: Write integration test for Kiosk flow (Idle -> Face detect -> Dispense -> Cooldown -> Reset)**
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement KioskHomeScreen and wire in main.dart**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**

---

### Task 9: Final Verification & Test Run

- [ ] **Step 1: Run `flutter test` across all unit and widget tests**
- [ ] **Step 2: Verify zero lint/compilation errors**
- [ ] **Step 3: Document walkthrough and user guide**
