//------------------------------------------------
// battleship.sv
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 14, 2016
// VLSI Final Project: Battleship
// Summary: The main file for Battleship
// TO DO: A lot of things...
// .........................
//------------------------------------------------


// Putting up placeholders for later
//
// NOTHING BELOW IS CORRECT AT ALL!
//                        ^
// READ THE ABOVE COMMENT |
//
module battleship(input logic ph1, ph2, reset, read, player, direction,
	              input logic [3:0] row, col,
                  output logic sclk, mosi);

    logic memread;
    logic memwrite;
    logic [2:0] row_addr; // 10 rows required
    logic [4:0] col_addr; // 20 columns required


    // Instantiate the FSM controller for the system
    controller c(ph1, ph2, reset, read, player, direction, row, col, row_addr, col_addr);

    // Instantiate the memory block for the system
    memory m(ph2, reset, memwrite, etc);

    // Instantiate the SPI module
    spi s(ph1, ph2, sclk, mosi);

endmodule

// SOME SETUP STARTED
module controller(input logic ph1, ph2, reset, read, player, direction,
                  input logic [3:0] row, col,
                  output logic [2:0] row_addr,
                  output logic [4:0] col_addr);
    
    logic [4:0] state, nextstate;

    // STATES
    parameter INITIAL_START     = 5'b00000;
    parameter LOAD_SHIP_DATA    = 5'b00001;
    parameter CHECK_POS_VALID   = 5'b00010;
    parameter SET_SHIP_POS      = 5'b00011;
    parameter GAME_START        = 5'b00100;
    parameter LOAD_SHOT_DATA    = 5'b00101;
    parameter CHECK_SHOT_VALID  = 5'b00110;
    parameter CHECK_HIT_MISS    = 5'b00111;
    parameter MARK_SHOT         = 5'b01000;
    parameter CHECK_SUNK        = 5'b01001;
    parameter CHECK_ALL_SUNK    = 5'b01010;
    parameter GAME_OVER         = 5'b01011;

    // nextstate logic
    always_comb
        case(state)
            INITIAL_START:
                begin
                    nextstate <= INITIAL_START;
                end
            default: nextstate <= INITIAL_START;
        endcase
    end

    // control signal logic
    always_comb
        case(state)
            INITIAL_START:
                begin
                    row_addr <= 3'b000;
                    col_addr <= 5'b00000;
                end
            default:
                begin
                    row_addr <= 3'b000;
                    col_addr <= 5'b00000;
                end;
        endcase
    end


endmodule

// DEFINTIELY NEEDS WORK
module memory(input ph2, reset, memwrite
              output etc);

endmodule


// DEFINITELY NEEDS WORK, I JUST COPY PASTED MY OLD MODULE FROM MICROPS
module spi(input logic clk, SCK, SSEL, MOSI, 
           output logic MISO, byte_received,
           output logic [7:0] byte_data_received);

// ------------------------------------------------
// Sample/Synchronize SPI signals (SCK, SSEL, MOSI) 
// using the FPGA clock and shift registers
// ------------------------------------------------

    logic SCK_risingedge, SCK_fallingedge, SSEL_active, 
          SSEL_startmessage, SSEL_endmessage, MOSI_data;
    logic [1:0] shift_MOSI;
    logic [2:0] shift_SCK, shift_SSEL;

    // Synchronize SCK, SSEL, and MOSI using 
    // two 3-bit shift reg and one 2-bit shift reg
    always_ff @(posedge clk) begin
        shift_SCK <= {shift_SCK, SCK};
        shift_SSEL <= {shift_SSEL, SSEL};
        shift_MOSI <= {shift_MOSI[0], MOSI};
    end

    always_comb begin
        SCK_risingedge = (shift_SCK[2:1] == 2'b01); // SCK rising edge logic
        SCK_fallingedge = (shift_SCK[2:1] == 2'b10); // SCK falling edge logic
        SSEL_active = ~shift_SSEL[1];  // SSEL is active low
        SSEL_startmessage = (shift_SSEL[2:1] == 2'b10); // msg starts @ falling edge
        SSEL_endmessage = (shift_SSEL[2:1] == 2'b01);  // msg stops @ rising edge
        MOSI_data = shift_MOSI[1];
    end


// -------------------------------------------
// Now receiving data from the SPI bus is easy
// -------------------------------------------
    
    logic [2:0] bitcnt;

    // Logic to receive data from MOSI
    always_ff @(posedge clk) begin
        // If the whole byte is received
        byte_received <= SSEL_active && SCK_risingedge && (bitcnt == 3'b111);

        // If chip select active, restart the bit count
        if (~SSEL_active)
            bitcnt <= 3'b000;
        else
            if (SCK_risingedge) begin
                bitcnt <= bitcnt + 1'b1; // Count on SCK rising edge
                // implement a shift-left register (since we receive the data MSB first)
                byte_data_received <= {byte_data_received[6:0], MOSI_data};
            end
    end


// -------------------------------------------
// Finally the transmission part
// -------------------------------------------

    logic [7:0] byte_data_sent, cnt;

    // Logic to transmit data through MISO
    always_ff @(posedge clk) begin
        if (SSEL_startmessage) begin
            cnt <= cnt+8'h1;  // count the messages
        end
        if (SSEL_active) begin
            if(SSEL_startmessage)
                byte_data_sent <= cnt;  // first byte sent in a message is the message count
            else
            if (SCK_fallingedge) begin
                if (bitcnt == 3'b000)
                    byte_data_sent <= 8'h00;  // after that, we send 0s
                else
                    byte_data_sent <= {byte_data_sent[6:0], 1'b0};
            end
        end
    end

    assign MISO = byte_data_sent[7];  // send MSB first
    // we assume that there is only one slave on the SPI bus
    // so we don't bother with a tri-state buffer for MISO
    // otherwise we would need to tri-state MISO when SSEL is inactive

endmodule
