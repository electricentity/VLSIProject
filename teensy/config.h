#define STEP_MS 10

#define NUM_INPUTS 12
#define NUM_OUTPUTS 12
#define NUM_POWERS 3
#define NUM_GROUNDS 3

const uint8_t powers[] = {P5, P37, P39};
const uint8_t grounds[] = {P4, P36, P40};

const uint8_t inputs[] = {P3, P16, P15, P14, // reset, read, player, direction
                          P10,P11,P12,P13, P6,P7,P8,P9}; // row<3:0>, col<3:0>


const uint8_t outputs[] = {P31,P30,P29,P28,P27,P26,P25,P24,P23,P22,P21,P20}; // data_out<11:0>

const uint8_t unused[] = {P1,P2, P32,P33,P34,P35, P38, 
                          P17,P18, P19}; // last three are ph1, ph2, data_ready
