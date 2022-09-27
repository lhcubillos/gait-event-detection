#include <Printers.h>

int received = 0;
int i;
// For communicating with zigbee

void setup()
{
  Serial.begin(115200);
  Serial1.begin(230400);
}

void loop()
{
  // check if the data is received
  char string[100];
  int idx = 0;
  if (Serial1.available() > 0)
  {
    delay(3);
    while (Serial1.available() > 0)
    {
      char c = Serial1.read();
      if (c != '.')
      {
        string[idx] = c;
        idx++;
      }
    }
  }

  if (idx > 0)
  {
    char ret_str[idx + 1];
    for (int i = 0; i < idx; i++)
    {
      ret_str[i] = 'A';
    }
    ret_str[idx] = '.';
    Serial.println(idx);
    int bytes = Serial1.write(ret_str);
    Serial.println(bytes);
    Serial.println(string);
  }
}
