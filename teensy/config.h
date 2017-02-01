#define STEP_MS 10

#define NUM_INPUTS 15
#define NUM_OUTPUTS 13
#define NUM_POWERS 3
#define NUM_GROUNDS 3

const uint8_t powers[] = {P5, P37, P39};
const uint8_t grounds[] = {P4, P36, P40};
const uint8_t inputs[] = {P3. P6,P7,P8,P9, P10,P11,P12,P13, // reset, col<3:0>, row<3:0>
                          P14, P15, P16}; , // direction, player, read, 
const uint8_t outputs[] = {P19, // data_ready
                           P20,P21,P22,P23,P24,P25,P26,P27,P28,P29,P30,P31}; // data_out<0:11>
const uint8_t unused[] = [P1,P2, P32,P33,P34,P35, P38, P17,P18]; // last two are ph1, ph2
