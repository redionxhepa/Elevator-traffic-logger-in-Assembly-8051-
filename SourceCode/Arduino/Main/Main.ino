#include <SoftwareSerial.h>
#include <SPI.h>
#include <SD.h>


const int chipSelect = 4;
SoftwareSerial mySerial(2, 3); //RX, TX

void setup() {
  Serial.begin(1200);
  mySerial.begin(1200);

  Serial.print("Initializing SD card...");
  // see if the card is present and can be initialized:
  while (!SD.begin(chipSelect)) {
  }
  Serial.println("card initialized.");
}




void loop() {
  if(mySerial.available() > 1){//Read from HC-12 and send to serial monitor
    String input = mySerial.readString();
    Serial.println(input);    

    // open the file. note that only one file can be open at a time,
    // so you have to close this one before opening another.
    File dataFile = SD.open("datalog.txt", FILE_WRITE);
  
    // if the file is available, write to it:
    if (dataFile) {
      dataFile.println(input);
      dataFile.close();
      // print to the serial port too:
      //Serial.println(dataString);
    }
    // if the file isn't open, pop up an error:
    else {
      Serial.println("error opening datalog.txt");
    }
  }
  
  delay(20);
}
