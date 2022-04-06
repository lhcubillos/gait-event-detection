#include <RTCZero.h>
#include <SPI.h>
#include <Wire.h>

/* Create an rtc object */
RTCZero rtc;

/* Change these values to set the current initial time */
const byte seconds = 0;
const byte minutes = 36;
const byte hours = 09;

/* Change these values to set the current initial date */
const byte day = 03;
const byte month = 11;
const byte year = 20;

void setup()
{
  Serial.begin(115200);

  rtc.begin(); // initialize RTC

  // Set the time
//  rtc.setHours(hours);
//  rtc.setMinutes(minutes);
//  rtc.setSeconds(seconds);
//
//  // Set the date
//  rtc.setDay(day);
//  rtc.setMonth(month);
//  rtc.setYear(year);

  // you can use also
  //rtc.setTime(hours, minutes, seconds);
  //rtc.setDate(day, month, year);
}

void loop()
{
  
  
}
