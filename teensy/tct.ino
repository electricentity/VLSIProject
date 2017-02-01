#include "pins.h"
#include "data.h"
#include "config.h"

bool read_outputs[NUM_OUTPUTS];
bool check_outputs[NUM_OUTPUTS];
bool read_inputs[NUM_INPUTS];

void setup() {
  Serial.begin(9600);
}

void init_pins(){
  uint8_t i = 0;
  while (i < NUM_GROUNDS){
    pinMode(grounds[i], OUTPUT);
    digitalWrite(grounds[i], 0);
    ++i;
  }
  i = 0;
  while (i < NUM_INPUTS){
    pinMode(inputs[i], INPUT);
    ++i;
  }
  i = 0;
  while (i < NUM_OUTPUTS){
    pinMode(outputs[i], OUTPUT);
    digitalWrite(outputs[i], 0);
    ++i;
  }
  i = 0;

  while (i < NUM_POWERS){
    pinMode(powers[i], OUTPUT);
    digitalWrite(powers[i], 1);
    ++i;
  }
}

void loop(){
  while (Serial.available() == 0){}
  Serial.read();
  //general purpose iterators
  uint16_t i = 0;
  unsigned long dt = 0;
  
  init_pins();
  
  uint8_t inp_mask = 0x80;
  uint8_t out_mask = 0x80;
  uint32_t err_count = 0;
  
  while (i < NUM_STEPS){
    uint32_t j = 0;
    
    while (j < NUM_INPUTS){
      uint16_t a = (i * NUM_INPUTS + j) >> 3;
      digitalWrite(inputs[j], input_vals[a] & inp_mask);
      read_inputs[j] = (input_vals[a] & inp_mask) ? 1 : 0;
      inp_mask = inp_mask >> 1;
      if (inp_mask == 0) inp_mask = 0x80;
      ++j;
    }
    
    j = 0;
    
    while (millis() < dt) {}
    dt = millis() + STEP_MS;
    
    byte check = 0;
    
    while (j < NUM_OUTPUTS){
      uint16_t a = (i * NUM_OUTPUTS + j) >> 3;
      check_outputs[j] = (output_vals[a] & out_mask) ? 1 : 0;
      out_mask = out_mask >> 1;
      if (out_mask == 0) out_mask = 0x80;
      read_outputs[j] = digitalRead(outputs[j]);
      if (read_outputs[j] != check_outputs[j]) check = 1;
      ++j;
    }
    j = 0;
    
    if (check){
      Serial.print("Discrepancy on step: ");
      Serial.print(i);
      Serial.println(".");
      Serial.print("Inputs: ");
      while (j < NUM_INPUTS){
        Serial.print(read_inputs[j]);
        ++j;
      }
      j=0;
      Serial.print("\nExpected outputs: ");
      while (j < NUM_OUTPUTS){
        Serial.print(check_outputs[j]);
        ++j;
      }
      j=0;
      Serial.print("\nActual outputs:   ");
      while (j < NUM_OUTPUTS){
        Serial.print(read_outputs[j]);
        ++j;
      }
      j=0;
      Serial.println();
      ++err_count;
    }
    ++i;
  }
  Serial.print("Test completed with ");
  Serial.print(err_count);
  Serial.println(" errors.");
  i=0;
  while (i < NUM_POWERS){
    digitalWrite(powers[i], 0);
    ++i;
  }  
}
