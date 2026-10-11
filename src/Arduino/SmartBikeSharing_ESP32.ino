#include <WiFi.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>
#include <WebServer.h>
#include <ESP32Servo.h>

// Wi-Fi credentials
const char* ssid = "Your Username";
const char* password = "Your Password";

// GPS and HTTP server
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);
WebServer server(80);
bool gpsDetected = false;

// Unique QR code identifier
const char* esp32ID = "8cC6adTpGRWFIf0nVIaSZUcuU8A3";

// Servo configuration
Servo myServo;
const int servoPin = 13;
bool scanConfirmed = false;
bool isUnlocked = false;

void unlockBike() {
  if (!isUnlocked) {
    Serial.println("Rotating servo to unlock");
    myServo.write(90);
    isUnlocked = true;
    delay(5000);
  } else {
    Serial.println("Bike is already unlocked!");
  }
}

void lockBike() {
  if (isUnlocked) {
    Serial.println("Locking bike (rotating servo to 0 degrees)");
    myServo.write(0);
    isUnlocked = false;
  } else {
    Serial.println("Bike is already locked!");
  }
}

void handleID() {
  server.send(200, "application/json", "{\"id\":\"" + String(esp32ID) + "\"}");
}

void handleScanConfirm() {
  scanConfirmed = true;
  Serial.println("Scan confirmed! Ready to unlock.");
  server.send(200, "application/json", "{\"status\":\"confirmed\"}");
}

void handleUnlock() {
  Serial.println("Unlock request received");
  if (scanConfirmed) {
    Serial.println("Scan confirmed! Unlocking bike...");
    unlockBike();
    scanConfirmed = false;
    server.send(200, "application/json", "{\"status\":\"unlocked\"}");
  } else {
    Serial.println("Scan not confirmed! Unlocking denied.");
    server.send(403, "application/json", "{\"error\":\"Scan not confirmed\"}");
  }
}

void handleLock() {
  Serial.println("Lock request received");
  lockBike();
  server.send(200, "application/json", "{\"status\":\"locked\"}");
}

void handleLocation() {
  if (!gpsDetected) {
    server.send(500, "application/json", "{\"error\":\"GPS module not detected\"}");
    return;
  }
  if (gps.location.isValid()) {
    String json = "{\"id\":\"" + String(esp32ID) + "\"," +
                  "\"lat\":" + String(gps.location.lat(), 6) + "," +
                  "\"lng\":" + String(gps.location.lng(), 6) + "}";
    server.send(200, "application/json", json);
  } else {
    server.send(500, "application/json", "{\"error\":\"No valid GPS signal\"}");
  }
}

void checkGPS() {
  static unsigned long lastCheck = 0;
  if (millis() - lastCheck > 5000) {
    lastCheck = millis();
    if (!gpsDetected) {
      Serial.println("GPS module not detected! Check wiring.");
    } else if (!gps.location.isValid()) {
      Serial.println("GPS signal not available. Waiting for fix...");
    } else {
      Serial.println("GPS working! Location: " +
                     String(gps.location.lat(), 6) + ", " +
                     String(gps.location.lng(), 6));
    }
  }
}

void setup() {
  Serial.begin(115200);
  // ESP32 RX = GPIO16, TX = GPIO17
  gpsSerial.begin(9600, SERIAL_8N1, 16, 17);

  myServo.attach(servoPin);
  myServo.write(0);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(1000);
  }
  Serial.println("\nConnected to WiFi, IP: " + WiFi.localIP().toString());

  server.on("/location", HTTP_GET, handleLocation);
  server.on("/get_id", HTTP_GET, handleID);
  server.on("/confirm_scan", HTTP_ANY, handleScanConfirm);
  server.on("/unlock", HTTP_ANY, handleUnlock);
  server.on("/lock", HTTP_ANY, handleLock);
  server.begin();
}

void loop() {
  while (gpsSerial.available()) {
    char c = gpsSerial.read();
    gps.encode(c);
    gpsDetected = true;
  }
  checkGPS();
  server.handleClient();
}
