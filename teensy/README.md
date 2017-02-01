# Teensy Chip Tester  
Cheap chip tester for 40-pin DIP chips, built around Teensy 3.6 development platform.  
![](https://github.com/wormyrocks/tct/raw/master/tct_example.jpg)
Takes in testvectors packed as a byte array and checks against expected outputs.  
Edit config.h to change runtime parameters and pin assignments.  
Edit data.h to pass input and output testvectors.  
testvector_gen.py generates sample testvector file corresponding to [CGoL](https://github.com/vaibhavviswanathan/CGoL).

