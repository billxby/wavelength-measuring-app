#include "AS726X.h"
#include <SoftwareSerial.h>

//Sensor Decration
AS726X sensor;
int data;
// SoftwareSerial bluetooth(0, 1);
int input;
int device = A1;

void setup() {
  Wire.begin();
  Serial.begin(9600);

  sensor.begin();
}

void loop() {
  
  //Prints all measurements

  if (Serial.available() > 0) {
    data = Serial.read();
    if (data != 0) {    
      Serial.println(data);

      if (data == 65) {    
        Serial.println("Turning on light");   
        sensor.enableBulb();
      }
      if (data == 66) {
        Serial.println("Turning off light");  
        sensor.disableBulb();
      }
      if (data == 67) {
        sensor.takeMeasurements();
        String buf;
        Serial.print("R");
        Serial.print(sensor.getCalibratedViolet(), 2);
        Serial.print(";");
        Serial.print(sensor.getCalibratedBlue(), 2);
        Serial.print(";");
        Serial.print(sensor.getCalibratedGreen(), 2);
        Serial.print(";");
        Serial.print(sensor.getCalibratedYellow(), 2);         Serial.print(";");
        Serial.print(sensor.getCalibratedOrange(), 2);
        Serial.print(";");
        Serial.print(sensor.getCalibratedRed(), 2);
        Serial.print("T");
      }
    }
        

  }

  delay (20);
);
}
