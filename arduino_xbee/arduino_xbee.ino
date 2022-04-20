#include <Printers.h>
#include <MKRIMU.h>

int received = 0;
int i;
// For communicating with zigbee

void sendSensorData();

// Time keeping
unsigned long previousMillis = 0; // last timechecked, in ms
unsigned long trialStart = 0;
bool sending_data = false;

void setup()
{
    Serial.begin(115200);
    Serial1.begin(230400);
    // begin initialization
    if (!IMU.begin())
    {
        Serial.println("Failed to initialize IMU!");
        while (1)
            ;
    }
    trialStart = millis();
}

void loop()
{
    unsigned long currentMillis = millis();
    if (Serial1.available() > 0)
    {
        char c = Serial1.read();
        // Starts with . and ends with ,
        if (c == '.')
        {
            sending_data = true;
            trialStart = millis();
            Serial.println("Trial Started");
        }
        // TODO: figure out a way to put into low power mode until
        // it receives a starting signal
        else if (c == ',')
        {
            sending_data = false;
            Serial.println("Trial stopped");
        }
    }
    if (sending_data && currentMillis - previousMillis >= 10)
    {
        if (IMU.accelerationAvailable())
        {
            previousMillis = currentMillis;
            sendSensorData();
        }
    }
}

// send IMU data
void sendSensorData()
{
    float eulers[3];
    float accel[3];
    float gyro[3];

    // read orientation x, y and z eulers
    IMU.readEulerAngles(eulers[0], eulers[1], eulers[2]);
    IMU.readAcceleration(accel[0], accel[1], accel[2]);
    IMU.readGyroscope(gyro[0], gyro[1], gyro[2]);
    unsigned long now = millis();
    unsigned long ts = (now + previousMillis) / 2 - trialStart;
    byte byteArray[4];
    byteArray[0] = (int)((ts >> 24) & 0xFF);
    byteArray[1] = (int)((ts >> 16) & 0xFF);
    byteArray[2] = (int)((ts >> 8) & 0XFF);
    byteArray[3] = (int)((ts & 0XFF));

    byte values[40];
    memcpy(values, (byte *)eulers, 12);
    memcpy(values + 12, (byte *)accel, 12);
    memcpy(values + 24, (byte *)gyro, 12);
    memcpy(values + 36, byteArray, 4);
    // Send all data
    Serial1.write(values, 40);
}
