
/*
  BLE IMU sketch on projecthub
  -----------------------------
  Arduino MKR 1010 + IMU Shield

  FOR USE WITH WEB APP DEMO AT :
  https://8bitkick.github.io/ArduinoBLE-IMU.html

  IMPORTANT - if required update MKR 1010 fw for bluetooth support first
  See https://forum.arduino.cc/index.php?topic=579306.0

*/

#include <ArduinoBLE.h>
#include <MKRIMU.h>

// BLE Service
BLEService imuService("917649A0-D98E-11E5-9EEC-000 2A5D5C51B"); // Custom UUID
// BLE Characteristic
BLECharacteristic imuCharacteristic("917649A1-D98E-11E5-9EEC-0002A5D5C51B", BLERead | BLENotify, 40);
BLECharacteristic latencyInCharacteristic("6192e000-3f65-4afa-91f5-3d671e525c45", BLEWriteWithoutResponse | BLEWrite, 40);
BLECharacteristic latencyOutCharacteristic("e83f52ee-0d66-4430-b171-92fc413631e2", BLERead | BLENotify, 40);

// Time keeping
unsigned long previousMillis = 0; // last timechecked, in ms
unsigned long trialStart = 0;

// Pins
int TTLPin = 6;

void setup()
{
  Serial.begin(115200); // initialize serial communication

  // Pins
  // initialize the built-in LED pin to indicate when a central is connected
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);
  pinMode(TTLPin, OUTPUT);
  digitalWrite(TTLPin, LOW);

  // begin initialization
  if (!IMU.begin())
  {
    Serial.println("Failed to initialize IMU!");
    while (1);
  }

  if (!BLE.begin())
  {
    Serial.println("starting BLE failed!");
    while (1);
  }

  // Setup bluetooth
  BLE.setLocalName("ArduinoIMU");
  BLE.setAdvertisedService(imuService);
  imuService.addCharacteristic(imuCharacteristic);
  imuService.addCharacteristic(latencyInCharacteristic);
  imuService.addCharacteristic(latencyOutCharacteristic);
  BLE.addService(imuService);

  latencyInCharacteristic.setEventHandler(BLEWritten, onLatencyInUpdate);
  // In intervals of 1.25ms  
  BLE.setConnectionInterval(2, 4);

  // start advertising
  BLE.advertise();
  Serial.println("Bluetooth device active, waiting for connections...");
}

// send IMU data
void sendSensorData()
{
  float eulers[3];
  float accel[3];
  float gyro[3];

  // read orientation x, y and z eulers
  IMU.readEulerAngles(eulers[0], eulers[1], eulers[2]);
  IMU.readAcceleration(accel[0],accel[1],accel[2]);
  IMU.readGyroscope(gyro[0],gyro[1],gyro[2]);
  unsigned long now = millis();
  unsigned long ts = (now + previousMillis) / 2 - trialStart;
  byte byteArray[4];
  byteArray[0] = (int)((ts >> 24) & 0xFF) ;
  byteArray[1] = (int)((ts >> 16) & 0xFF) ;
  byteArray[2] = (int)((ts >> 8) & 0XFF);
  byteArray[3] = (int)((ts & 0XFF));

  byte values[40];
  memcpy(values, (byte *)eulers, 12);
  memcpy(values+12, (byte *)accel, 12);
  memcpy(values+24, (byte *)gyro, 12);
  memcpy(values+36, byteArray, 4);
  // Send all data
  imuCharacteristic.setValue((byte *)&values, 40);
}

void onLatencyInUpdate(BLEDevice central, BLECharacteristic characteristic) {
  // central wrote new value to characteristic
  byte test[40];
  latencyInCharacteristic.readValue(test, 40);
  latencyOutCharacteristic.setValue(test, 40);
}

void loop()
{
  // wait for a BLE central
  BLEDevice central = BLE.central();

  // if a BLE central is connected to the peripheral:
  if (central)
  {
    Serial.print("Connected to central: ");
    // print the central's BT address:
    Serial.println(central.address());
    // turn on the LED to indicate the connection:
    digitalWrite(LED_BUILTIN, HIGH);
    // Wait for 2s, and then generate TTL pulse
    delay(2000);
    digitalWrite(TTLPin,HIGH);
    delay(25);
    digitalWrite(TTLPin,LOW);
    trialStart = millis();

    // while the central is connected:
    while (central.connected())
    {
      unsigned long currentMillis = millis();
      if (currentMillis - previousMillis >= 10)
      {
        if (IMU.accelerationAvailable())
        {
          previousMillis = currentMillis;
          sendSensorData();
        }
      }
    }
    // when the central disconnects, turn off the LED:
    digitalWrite(LED_BUILTIN, LOW);
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}
