#include "pins.h"
#include "data.h"
#include "config.h"

bool read_outputs[NUM_OUTPUTS];
bool check_outputs[NUM_OUTPUTS];
bool read_inputs[NUM_INPUTS];

void init_pins(){

  uint8_t i = 0;


  // // Set the grounds to 0
  // for (i = 0; i < NUM_GROUNDS; i++) {

  //   pinMode(grounds[i], OUTPUT);
  //   digitalWrite(grounds[i], 0);

  // }

  // Set the inputs to be outputs from the teensy
  for (i = 0; i < NUM_INPUTS; i++) {

    pinMode(inputs[i], OUTPUT);
    digitalWrite(inputs[i], 0);

  }

  // Set the clocks to be outputs from the teensy
  for (i = 0; i < NUM_CLOCKS; i++) {

    pinMode(clocks[i], OUTPUT);
    digitalWrite(clocks[i], 0);

  }

  // Set the outputs to be inputs to the teens
  for (i = 0; i < NUM_OUTPUTS; i++) {

    pinMode(outputs[i], INPUT);

  }

  // // Set the powers to be logic 1
  // for (i = 0; i < NUM_POWERS; i++) {

  //   pinMode(powers[i], OUTPUT);
  //   digitalWrite(powers[i], 1);

  // }
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
  uint16_t vector_num = 0; //Increments with the clock cycle
  uint32_t j = 0; //General purpose counter

  unsigned long dt = 0;
  bool new_vector = 1; // Start by reading in new vector
  bool data_ready = 0;

  bool check = 0; //Indicates whether the testvector passed
  

  uint16_t inp_mask = 0x0800; //Masked used for interacting with input
  uint16_t out_mask = 0x0800; //Mask used for interacting with output
  uint32_t err_count = 0; //Counts the number of errors
  
  // Loop through the vectors until you go through all of them
  while (vector_num < NUMBER_OF_VETORS){

    if (new_vector) {

      new_vector = 0;

      //Loop through the input pins
      for (j = 0; j < NUM_INPUTS; j++) {

        // Write the single bit to the pin
        digitalWrite(inputs[j], input_vals[vector_num] & inp_mask);

        // Save the value written to the read_inputs array
        read_inputs[j] = (input_vals[vector_num] & inp_mask) ? 1 : 0;

        // Shift the mask for the next bit
        inp_mask = inp_mask >> 1;

      }

      // Reset the input mask
      inp_mask = 0x0800;

      // Loop through the outputs
      for (j = 0; j < NUM_OUTPUTS; j++) {

        // Save the value value to the check_outputs array
        check_outputs[j] = (output_vals[vector_num] & out_mask) ? 1 : 0;

        // shift the mask for the next bit
        out_mask = out_mask >> 1;

      }

      // Reset the output mask
      out_mask = 0x0800;

    }
    
    // The rising of ph1
    digitalWrite(clocks[0], 1);

    // Wait for 10ms
    while (millis() < dt) {}
    dt = millis() + STEP_MS;

    // The falling of ph1
    digitalWrite(clocks[0], 0);

    // Wait for 10ms
    while (millis() < dt) {}
    dt = millis() + STEP_MS;
    
    // The rising of ph2
    digitalWrite(clocks[1], 1);

    // Read data_ready signal
    data_ready = digitalRead(DATA_READY);

    // If there is data ready read in the outputs and verify
    if (data_ready) {

      // Loop through the outputs
      for (j = 0; j < NUM_OUTPUTS; j++) {

        // Read the pin and store in the read_outputs array
        read_outputs[j] = digitalRead(outputs[j]);

        // Check each value to verify the output was correct
        if (read_outputs[j] != check_outputs[j]) check = 1;

      }

      // If the output was incorrect write out an error message
      if (check){

        Serial.print("Discrepancy on step: ");
        Serial.print(vector_num);
        Serial.println(".");
        Serial.print("Inputs: ");

        for (j = 0; j < NUM_INPUTS; j++) {

          Serial.print(read_inputs[j]);

        }

        Serial.print("\nExpected outputs: ");

        for (j = 0; j < NUM_OUTPUTS; j++) {

          Serial.print(check_outputs[j]);

        }

        Serial.print("\nActual outputs:   ");

        for (j = 0; j < NUM_OUTPUTS; j++) {

          Serial.print(read_outputs[j]);

        }

        Serial.println();

        // increment the error count
        ++err_count;
      }

      // Set up for next vector
      vector_num++;
      new_vector = 1;

    }
    
    // Wait for 10ms
    while (millis() < dt) {}
    dt = millis() + STEP_MS;

    // The falling of ph2
    digitalWrite(clocks[1], 0);    

    // Wait for 10ms
    while (millis() < dt) {}
    dt = millis() + STEP_MS;

    
  }

  // All tests have been run, output final result
  Serial.print("Test completed with ");
  Serial.print(err_count);
  Serial.println(" errors.");

  // // Turn off the chip
  // for (j = 0; j < NUM_POWERS; j++) {  

  //   digitalWrite(powers[j], 0);

  // }  
  
}
