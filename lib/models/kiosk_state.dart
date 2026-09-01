enum KioskStatus {
  idle, // Waiting for user to approach camera
  scanning, // Face detected, analyzing & verifying cooldown
  dispensing, // Dispenser hardware/demo rolling paper
  success, // Paper dispensed successfully
  cooldown, // User in cooldown cooldown timer active
  error, // Hardware error (jammed, out of paper, connection fail)
}

enum ConnectionMode {
  demo,
  http,
  websocket,
  mqtt,
}
