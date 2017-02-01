#include "pins.h"
#include "data.h"
#include "config.h"

bool read_outputs[NUM_OUTPUTS];
bool check_outputs[NUM_OUTPUTS];
bool read_inputs[NUM_INPUTS];

void init_pins(){
  uint8_t i = 0;


  while (i < NUM_GROUNDS){
    pinMode(grounds[i], OUTPUT);
    digitalWrite(grounds[i], 0);
    ++i;
  }
  i = 0;
  while (i < NUM_INPUTS){
    pinMode(inputs[i], OUTPUT);
    digitalWrite(inputs[i], 0);
    ++i;
  }
  i = 0;
  while (i < NUM_OUTPUTS){
    pinMode(outputs[i], INPUT);
    ++i;
  }
  i = 0;
  while (i < NUM_POWERS){
    pinMode(powers[i], OUTPUT);
    digitalWrite(powers[i], 1);
    ++i;
  }
}

void setup() {
  Serial.begin(9600);

  init_pins();
}

void loop(){

  //Wait until the serial connection is initialized
  while (Serial.available() == 0){}
  Serial.read();

  //general purpose iterators
  uint16_t i = 0; //Increments with the clock cycle
  uint32_t j = 0; //General purpose counter

  unsigned long dt = 0;

  byte check = 0; //Indicates whether the testvector passed
  

  uint8_t inp_mask = 0x80; //Masked used for interacting with input
  uint8_t out_mask = 0x80; //Mask used for interacting with output
  uint32_t err_count = 0; //Counts the number of errors
  
  while (i < NUM_STEPS){
    j = 0;
    
    //Loop through the input pins
    while (j < NUM_INPUTS){

      // Find the index for accessing the input_val array
      // ((number of clock cycles) * (number of inputs) + the current input pin) / (size of elements in array)
      uint16_t a = (i * NUM_INPUTS + j) >> 3;

      // Write the single bit to the pin
      digitalWrite(inputs[j], input_vals[a] & inp_mask);

      // Save the value written to the read_inputs array
      read_inputs[j] = (input_vals[a] & inp_mask) ? 1 : 0;

      // Shift the mask for the next bit
      inp_mask = inp_mask >> 1;

      // If the mask has been completely shifted reset it
      if (inp_mask == 0) inp_mask = 0x80;

      // Increment j
      ++j;
    }
    
    j = 0;
    
    // Wait for 10ms
    while (millis() < dt) {}
    dt = millis() + STEP_MS;
    
    // Loop through the outputs
    while (j < NUM_OUTPUTS){

      // Find the index for accessing the output_val array
      // ((number of clock cycles) * (number of outputs) + the current output pin) / (size of elements in array)
      uint16_t a = (i * NUM_OUTPUTS + j) >> 3;

      // Save the value value to the check_outputs array
      check_outputs[j] = (output_vals[a] & out_mask) ? 1 : 0;

      // shift the mask for the next bit
      out_mask = out_mask >> 1;

      // If the mask has been completely shifted reset it
      if (out_mask == 0) out_mask = 0x80;

      // Read the pin and store in the read_outputs array
      read_outputs[j] = digitalRead(outputs[j]);

      // Check each value to verify the output was correct
      if (read_outputs[j] != check_outputs[j]) check = 1;

      // increment j
      ++j;
    }

    j = 0;
    

    // If the output was incorrect write out an error message
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

      // increment the error count
      ++err_count;
    }
    ++i;
  }

  // All tests have been run, output final result
  Serial.print("Test completed with ");
  Serial.print(err_count);
  Serial.println(" errors.");

  // Turn off the chip
  i=0;
  while (i < NUM_POWERS){
    digitalWrite(powers[i], 0);
    ++i;
  }  
}
