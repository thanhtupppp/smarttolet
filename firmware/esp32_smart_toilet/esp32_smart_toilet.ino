/*
 * =====================================================================================
 *  SMART TOILET PAPER DISPENSER - ESP32 FIRMWARE
 * =====================================================================================
 *  Mã nguồn điều khiển phần cứng Kiosk Cấp Giấy Vệ Sinh Tự Động bằng ESP32
 *  - Giao tiếp: HTTP REST API & WebSocket Realtime Server
 *  - Động cơ: Điều khiển tốc độ qua PWM + Đảo chiều mạch cầu H (L298N / TB6612FNG)
 *  - Cảm biến: Ngắt ngoài Encoder ISR đo chính xác chiều dài giấy (cm)
 *  - Cảm biến hết giấy: Cảm biến quang hồng ngoại / công tắc hành trình
 *  - Wi-Fi: Tự động kết nối Router hoặc phát Access Point fallback "SmartToilet-AP"
 * =====================================================================================
 */

#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <AsyncTCP.h>
#include <ArduinoJson.h>

// ==========================================
// 1. CẤU HÌNH PINOUT PHẦN CỨNG (GPIO)
// ==========================================
// Điều khiển Motor DC (Cầu H L298N / TB6612)
#define PIN_MOTOR_PWM       18  // Chân PWM điều tốc độ động cơ
#define PIN_MOTOR_IN1       19  // Chân hướng 1
#define PIN_MOTOR_IN2       21  // Chân hướng 2

// Cảm biến Encoder đo chiều dài giấy
#define PIN_ENCODER_A       34  // Kênh A ngắt ngoài (ISR)
#define PIN_ENCODER_B       35  // Kênh B (tùy chọn đo chiều)

// Cảm biến phát hiện hết giấy (IR Optical Sensor / Switch)
#define PIN_PAPER_SENSOR    32  // LOW: có giấy, HIGH: hết giấy

// Đèn LED chỉ báo trạng thái
#define PIN_STATUS_LED      2   // LED onboard ESP32

// Cấu hình PWM
#define PWM_CHANNEL         0
#define PWM_FREQ            5000
#define PWM_RESOLUTION      8   // 0 - 255
#define MOTOR_DEFAULT_SPEED 220 // Tốc độ chạy motor (0 - 255)

// ==========================================
// 2. CẤU HÌNH WI-FI & THÔNG SỐ HỆ THỐNG
// ==========================================
const char* WIFI_SSID     = "SmartToilet_WiFi";
const char* WIFI_PASS     = "12345678";

// Access Point Fallback nếu không kết nối được WiFi
const char* AP_SSID       = "SmartToilet-AP";
const char* AP_PASS       = "12345678";

// Tỉ lệ xung Encoder (10 xung = 1 cm giấy) - có thể điều chỉnh qua App
volatile int pulsesPerCm  = 10;

// ==========================================
// 3. KHỞI TẠO BIẾN HỆ THỐNG & WEBSERVER
// ==========================================
AsyncWebServer server(80);
AsyncWebSocket ws("/ws");

enum DispenserState {
  STATE_IDLE,
  STATE_DISPENSING,
  STATE_STOPPED,
  STATE_ERROR_JAM,
  STATE_PAPER_EMPTY
};

volatile DispenserState currentState = STATE_IDLE;
volatile long encoderPulseCount = 0;
volatile long targetPulses = 0;
int currentTargetCm = 0;
unsigned long dispenseStartTime = 0;
const unsigned long TIMEOUT_JAM_MS = 10000; // Timeout 10s nếu kẹt giấy / motor không quay

// Ngắt ngoài đếm xung Encoder (ISR)
void IRAM_ATTR onEncoderPulse() {
  encoderPulseCount++;
}

// ==========================================
// 4. HÀM ĐIỀU KHIỂN MOTOR
// ==========================================
void setupMotor() {
  pinMode(PIN_MOTOR_IN1, OUTPUT);
  pinMode(PIN_MOTOR_IN2, OUTPUT);
  pinMode(PIN_STATUS_LED, OUTPUT);
  pinMode(PIN_PAPER_SENSOR, INPUT_PULLUP);
  pinMode(PIN_ENCODER_A, INPUT_PULLUP);

  attachInterrupt(digitalPinToInterrupt(PIN_ENCODER_A), onEncoderPulse, RISING);

  ledcAttach(PIN_MOTOR_PWM, PWM_FREQ, PWM_RESOLUTION);
  stopMotor();
}

void startMotor(int speed) {
  digitalWrite(PIN_MOTOR_IN1, HIGH);
  digitalWrite(PIN_MOTOR_IN2, LOW);
  ledcWrite(PIN_MOTOR_PWM, speed);
  digitalWrite(PIN_STATUS_LED, HIGH);
}

void stopMotor() {
  digitalWrite(PIN_MOTOR_IN1, LOW);
  digitalWrite(PIN_MOTOR_IN2, LOW);
  ledcWrite(PIN_MOTOR_PWM, 0);
  digitalWrite(PIN_STATUS_LED, LOW);
}

bool isPaperEmpty() {
  return digitalRead(PIN_PAPER_SENSOR) == HIGH;
}

// ==========================================
// 5. GIAO TIẾP WEBSOCKET & REST API
// ==========================================
void broadcastWsStatus(const char* type, int currentCm, int targetCm, float progress) {
  if (ws.count() == 0) return;
  StaticJsonDocument<200> doc;
  doc["type"] = type;
  doc["current_cm"] = currentCm;
  doc["target_cm"] = targetCm;
  doc["progress"] = progress;
  doc["paper_empty"] = isPaperEmpty();
  
  String jsonString;
  serializeJson(doc, jsonString);
  ws.textAll(jsonString);
}

void onWsEvent(AsyncWebSocket *server, AsyncWebSocketClient *client, AwsEventType type, void *arg, uint8_t *data, size_t len) {
  if (type == WS_EVT_CONNECT) {
    Serial.printf("[WebSocket] Client connected: #%u\n", client->id());
  } else if (type == WS_EVT_DISCONNECT) {
    Serial.printf("[WebSocket] Client disconnected: #%u\n", client->id());
  }
}

void setupServer() {
  ws.onEvent(onWsEvent);
  server.addHandler(&ws);

  // Endpoint 1: Health Check (Kiểm tra sống sót)
  server.on("/health", HTTP_GET, [](AsyncWebServerRequest *request) {
    StaticJsonDocument<200> doc;
    doc["status"] = "ok";
    doc["device"] = "ESP32_SMART_TOILET";
    doc["uptime_sec"] = millis() / 1000;
    doc["paper_sensor"] = isPaperEmpty() ? "EMPTY" : "READY";
    doc["state"] = currentState == STATE_DISPENSING ? "dispensing" : "idle";
    
    String response;
    serializeJson(doc, response);
    request->send(200, "application/json", response);
  });

  // Endpoint 2: Cấp giấy (POST /dispense)
  server.on("/dispense", HTTP_POST, [](AsyncWebServerRequest *request) {}, NULL, 
    [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
      if (currentState == STATE_DISPENSING) {
        request->send(409, "application/json", "{\"error\":\"Motor is already dispensing\"}");
        return;
      }

      if (isPaperEmpty()) {
        request->send(400, "application/json", "{\"error\":\"Paper roll is empty\"}");
        return;
      }

      StaticJsonDocument<200> doc;
      DeserializationError error = deserializeJson(doc, data, len);
      if (error) {
        request->send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
        return;
      }

      int lengthCm = doc["length_cm"] | 70;
      if (lengthCm <= 0 || lengthCm > 200) lengthCm = 70;

      // Cập nhật cấu hình xung nếu có
      if (doc.containsKey("pulse_per_cm")) {
        pulsesPerCm = doc["pulse_per_cm"];
      }

      // Khởi động chu trình nhả giấy
      currentTargetCm = lengthCm;
      targetPulses = lengthCm * pulsesPerCm;
      encoderPulseCount = 0;
      dispenseStartTime = millis();
      currentState = STATE_DISPENSING;
      startMotor(MOTOR_DEFAULT_SPEED);

      StaticJsonDocument<200> res;
      res["status"] = "dispensing";
      res["target_cm"] = lengthCm;
      res["target_pulses"] = targetPulses;

      String response;
      serializeJson(res, response);
      request->send(200, "application/json", response);
  });

  // Endpoint 3: Dừng khẩn cấp (POST /stop)
  server.on("/stop", HTTP_POST, [](AsyncWebServerRequest *request) {
    stopMotor();
    currentState = STATE_STOPPED;
    broadcastWsStatus("stopped", 0, 0, 0);
    request->send(200, "application/json", "{\"status\":\"stopped\"}");
  });

  // Endpoint 4: Trạng thái hiện tại (GET /status)
  server.on("/status", HTTP_GET, [](AsyncWebServerRequest *request) {
    int currentCm = encoderPulseCount / pulsesPerCm;
    StaticJsonDocument<200> doc;
    doc["state"] = currentState;
    doc["current_cm"] = currentCm;
    doc["target_cm"] = currentTargetCm;
    doc["paper_empty"] = isPaperEmpty();

    String response;
    serializeJson(doc, response);
    request->send(200, "application/json", response);
  });

  server.begin();
}

// ==========================================
// 6. KHỞI TẠO HỆ THỐNG (SETUP)
// ==========================================
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n==========================================");
  Serial.println("  SMART TOILET PAPER DISPENSER FIRMWARE");
  Serial.println("==========================================");

  setupMotor();

  // Kết nối WiFi Station
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("[WiFi] Dang ket noi toi: ");
  Serial.println(WIFI_SSID);

  unsigned long startAttemptTime = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 8000) {
    delay(300);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WiFi] Ket noi thanh cong!");
    Serial.print("[WiFi] Dia chi IP ESP32: ");
    Serial.println(WiFi.localIP());
  } else {
    // Phát Access Point nếu không có mạng WiFi ngoài
    Serial.println("\n[WiFi] Ket noi that bai! Khoi dong Access Point Fallback...");
    WiFi.mode(WIFI_AP);
    WiFi.softAP(AP_SSID, AP_PASS);
    Serial.print("[WiFi AP] IP Access Point: ");
    Serial.println(WiFi.softAPIP());
  }

  setupServer();
  Serial.println("[System] WebServer & WebSocket Server da san sang!");
}

// ==========================================
// 7. VÒNG LẶP CHÍNH (LOOP)
// ==========================================
unsigned long lastWsBroadcastTime = 0;

void loop() {
  ws.cleanupClients();

  if (currentState == STATE_DISPENSING) {
    long currentPulses = encoderPulseCount;
    int currentCm = currentPulses / pulsesPerCm;
    float progress = (float)currentPulses / (float)targetPulses;
    if (progress > 1.0) progress = 1.0;

    // Định kỳ 100ms phát telemetry qua WebSocket về điện thoại
    if (millis() - lastWsBroadcastTime >= 100) {
      lastWsBroadcastTime = millis();
      broadcastWsStatus("progress", currentCm, currentTargetCm, progress);
    }

    // 1. Kiểm tra đạt độ dài định mức
    if (currentPulses >= targetPulses) {
      stopMotor();
      currentState = STATE_IDLE;
      broadcastWsStatus("completed", currentTargetCm, currentTargetCm, 1.0);
      Serial.printf("[Dispense] Da hoan thanh cap %d cm giay!\n", currentTargetCm);
    }
    // 2. Kiểm tra cảm biến hết giấy
    else if (isPaperEmpty()) {
      stopMotor();
      currentState = STATE_PAPER_EMPTY;
      broadcastWsStatus("paper_empty", currentCm, currentTargetCm, progress);
      Serial.println("[Warning] Phat hien het giay trong khi nhay!");
    }
    // 3. Kiểm tra kẹt giấy (Sau 2.5 giây không có xung encoder nào tăng)
    else if (millis() - dispenseStartTime > TIMEOUT_JAM_MS) {
      stopMotor();
      currentState = STATE_ERROR_JAM;
      broadcastWsStatus("error_jam", currentCm, currentTargetCm, progress);
      Serial.println("[Error] Ket giay hoac motor khong quay (Timeout)!");
    }
  }

  delay(5);
}
