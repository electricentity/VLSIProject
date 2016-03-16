# VLSIProject

So most of what I have done thus far is in GeneralOutline.txt. I have just been trying to slowly flush out what each step is doing. If you want to make any changes to what I have done thus far go ahead, just commit it and I can review what has been changed. You're welcome to start working on the SPI and the SRAM if you want, I probably won't start on any actual code for a couple days. I'm going to focus most of my energy on trying to really wrap my head around all of the workings of the FSM and make sure I understand what all needs to be occurring before I even contemplate writing any verilog. 

You should be able to get Quartus Web edition on your computer so you can run modelsim and shit. We should also keep in mind how we are going to be testing everything. I bet we could probably write some simple testvectors for the SPI if you want to test that since it is a pretty standalone part of the system. 

I also threw some pictures I took of the returned project proposal on the drive if you want to look at that.

## TODO
1. Write out all of the states for FMS
  * How are we accessing the memory?
  * How do we want to handle all of the ship checking?
  * Is there a way for us to make some of the processes use the same logic?
2. Write Verilog
  * SPI
  * SRAM
  * Controller
  * Test Vectors
