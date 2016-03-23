//------------------------------------------------
// battleship.sv
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
//------------------------------------------------


//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: Controller (FSM)
// Summary: The module for the controller/fsm
//------------------------------------------------
module battleship(input logic ph1, ph2, reset, read, player, direction,
	              input logic [3:0] row, col,
                  output logic data_ready,
                  output logic [11:0] data_out);

    logic       write_enable[1:0], write_enable_ss[1:0];
    logic [1:0] write_data[1:0], read_data[1:0];
    logic [2:0] ship_addr[1:0];
    logic [3:0] row_addr[1:0], col_addr[1:0]; // 10 rows/columns required
    logic [8:0] write_data_ss[1:0], read_data_ss[1:0];

    // Instantiate the FSM controller for the system
    controller c(ph1, ph2, reset, read, player, direction,
                 row, col, write_data, read_data,
                 write_data_ss, read_data_ss,
                 row_addr, col_addr, ship_addr,
                 write_enable, write_enable_ss,
                 data_ready, data_out);

    // Instantiate the memory block for the system
    gb_mem gameboard1(ph2, reset, write_enable[0],
                      row_addr[0], col_addr[0], write_data[0], read_data[0]);

    gb_mem gameboard2(ph2, reset, write_enable[1],
                      row_addr[1], col_addr[1], write_data[1], read_data[1]);

    ss_mem shipstorage1(ph2, reset, write_enable_ss[0],
                        ship_addr[0], write_data[0], read_data[0]);

    ss_mem shipstorage2(ph2, reset, write_enable_ss[1],
                        ship_addr[1], write_data_ss[1], read_data_ss[1]);
endmodule


//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: Controller (FSM)
// Summary: The module for the controller/fsm
//------------------------------------------------
module controller(input logic ph1, ph2, reset, read, player, direction,
                  input logic [3:0] row, col,
                  input logic [1:0] read_data[1:0],
                  input logic [8:0] read_data_ss[1:0],
                  output logic [1:0] write_data[1:0],
                  output logic [8:0] write_data_ss[1:0], 
                  output logic [3:0] row_addr[1:0], col_addr[1:0],
                  output logic [2:0] ship_addr[1:0],
                  output logic write_enable[1:0], write_enable_ss[1:0], data_ready,
                  output logic [11:0] data_out);
    
    logic valid, expected_player, finished_ship, hit, all_ships;
    logic input_player, input_direction;
    logic [2:0] size, ship_len; // counter
    logic [2:0] sunk_count[1:0], sunk_count_old[1:0];
    logic [3:0] input_row, input_col;
    logic [4:0] state, nextstate, hold_nextstate;
    logic [2:0] ship_sizes[4:0] = '{3'b101, 3'b100, 3'b011, 3'b011, 3'b010};

    flopenr #5 statereg(ph1, ph2, reset, 1'b1, nextstate, state);

    // STATES
    parameter INITIAL_START     = 5'b00000;
    parameter LOAD_SHIP_DATA    = 5'b00001;
    parameter CHECK_PLAYER      = 5'b00010;
    parameter ON_BOARD_SET      = 5'b00011;
    parameter ON_BOARD_CHECK    = 5'b00100;
    parameter CHECK_CELLS       = 5'b00101;
    parameter SET_SHIP_POS      = 5'b00110;
    parameter GAME_START        = 5'b00111;
    parameter LOAD_SHOT_DATA    = 5'b01000;
    parameter CHECK_PLAYER2     = 5'b01001;
    parameter ON_BOARD_SET2     = 5'b01010;
    parameter ON_BOARD_CHECK2   = 5'b01011;
    parameter CHECK_SHOT_VALID  = 5'b01100;
    parameter CHECK_SHOT_VALID2 = 5'b01101;
    parameter MARK_SHOT         = 5'b01110;
    parameter GET_SHIP_INFO     = 5'b01111;
    parameter CHECK_SUNK        = 5'b10000;
    parameter CHECK_ALL_SUNK    = 5'b10001;
    parameter GAME_OVER         = 5'b10010;
    parameter DATA_SETUP        = 5'b10011;
    parameter DATA_SEND         = 5'b10100;

    // nextstate logic
    always_comb
        begin
            case(state)
                // Reset/set all values as necessary
                INITIAL_START: nextstate = LOAD_SHIP_DATA;
                // Load in player inputs and save them, reset some values, set valid
                LOAD_SHIP_DATA:
                    begin
                        if (read) nextstate = CHECK_PLAYER;
                        else      nextstate = LOAD_SHIP_DATA;
                    end
                // Check that the correct player in inputting
                CHECK_PLAYER:
                    begin
                        if (valid) nextstate = ON_BOARD_SET;
                        else       nextstate = LOAD_SHIP_DATA;
                    end
                // Check if ship placement would be out of bounds or not, set valid
                ON_BOARD_SET: nextstate = ON_BOARD_CHECK;
                // If valid is set to 1 above, go to check cells. Else, get new inputs
                ON_BOARD_CHECK:
                    begin
                        if (valid) nextstate = CHECK_CELLS;
                        else       nextstate = DATA_SETUP;
                    end
                // After checking all cells ship could be on, determine whether or not
                // to set the ship there (are there any collisions with other ships)
                CHECK_CELLS:
                    begin
                        if (finished_ship)
                            begin
                                if (valid) nextstate = SET_SHIP_POS;
                                else       nextstate = DATA_SETUP;
                            end
                        else               nextstate = CHECK_CELLS;
                    end
                // If above checks work correctly, place the ship on the board
                // Change expected inputs to next ship or next player accordingly
                SET_SHIP_POS:
                    begin
                        if (~finished_ship)
                            begin
                                if (all_ships) nextstate = GAME_START;
                                else           nextstate = LOAD_SHIP_DATA;
                            end
                        else                   nextstate = DATA_SETUP;
                    end
                // Load other stuff; This is a transition state. Reset any values
                GAME_START: nextstate = LOAD_SHOT_DATA;
                // State will handle player inputs, set valid
                LOAD_SHOT_DATA:
                    begin
                        if (read) nextstate = CHECK_PLAYER2;
                        else      nextstate = LOAD_SHOT_DATA;
                    end
                // If the player is correct check the board, otherwise ask for new inputs
                CHECK_PLAYER2:
                    begin
                        if (valid) nextstate = ON_BOARD_SET2;
                        else       nextstate = DATA_SETUP;

                    end
                // Check if ship placement would be out of bounds or not, set valid
                ON_BOARD_SET2: nextstate = ON_BOARD_CHECK2;
                // If valid is set to 1 above, go to check cells. Else, rerun the inputs
                ON_BOARD_CHECK2:
                    begin
                        if (valid) nextstate = CHECK_SHOT_VALID;
                        else       nextstate = DATA_SETUP;
                    end
                // Check if the shot is valid; IE shot in bounds, not shot already, set shot_valid
                // Also set hit and enable writing to desired board
                CHECK_SHOT_VALID: nextstate = CHECK_SHOT_VALID2;
                // Check shot_valid and move on or ask for new inputs 
                CHECK_SHOT_VALID2:
                    begin
                        if (valid) nextstate = MARK_SHOT;
                        else       nextstate = DATA_SETUP;
                    end
                // Save shot, if hit go to CHECK_SUNK, else go to LOAD_SHOT_DATA
                MARK_SHOT:
                    begin
                        if (hit) nextstate = GET_SHIP_INFO;
                        else     nextstate = DATA_SETUP;
                    end
                // Get the info for the position of the next ship to check
                GET_SHIP_INFO:
                    begin
                        nextstate = CHECK_SUNK;
                    end
                // Check if the ship is sunk or not and set up for next ship
                CHECK_SUNK:
                    begin
                        if (finished_ship)
                            begin 
                                if (all_ships) nextstate = CHECK_ALL_SUNK;
                                else           nextstate = GET_SHIP_INFO;
                            end
                        else                   nextstate = CHECK_SUNK;
                    end
                // Check to see if all ships are sunk
                CHECK_ALL_SUNK:
                    begin
                        if (sunk_count[~input_player] == 3'b101) nextstate = DATA_SETUP;
                        else                                     nextstate = DATA_SETUP;
                    end
                // Game over, someone won
                GAME_OVER: nextstate = DATA_SEND;
                DATA_SETUP: nextstate = DATA_SEND;
                DATA_SEND: nextstate = hold_nextstate;
                default: nextstate = INITIAL_START;
            endcase
        end

    // hold_nextstate logic for sending data_out
    always_comb
        begin
            case(state)
                // Go back to LOAD_SHIP_DATA after sending data
                ON_BOARD_CHECK: hold_nextstate = LOAD_SHIP_DATA;
                // Go back to LOAD_SHIP_DATA after sending data
                CHECK_CELLS: hold_nextstate = LOAD_SHIP_DATA;
                // Loop through and send data in SET_SHIP_POS
                SET_SHIP_POS: hold_nextstate = SET_SHIP_POS;
                CHECK_PLAYER2: hold_nextstate = LOAD_SHOT_DATA;
                // If valid is set to 1 above, go to check cells. Else, rerun the inputs
                ON_BOARD_CHECK2: hold_nextstate = LOAD_SHOT_DATA;
                // Check shot_valid and move on or ask for new inputs 
                CHECK_SHOT_VALID2: hold_nextstate = LOAD_SHOT_DATA;
                // Save shot, if hit go to CHECK_SUNK, else go to LOAD_SHOT_DATA
                MARK_SHOT: hold_nextstate = LOAD_SHOT_DATA;
                CHECK_ALL_SUNK:
                    begin
                        if (sunk_count[~input_player] == 3'b101) hold_nextstate = GAME_OVER;
                        else                                     hold_nextstate = LOAD_SHOT_DATA;
                    end
                GAME_OVER: hold_nextstate = GAME_OVER;
                default: hold_nextstate = INITIAL_START;
            endcase
        end

    // control signal logic
    always_comb
        begin
            case(state)
                INITIAL_START: expected_player = 1'b0; //Start with player 1
                LOAD_SHIP_DATA:
                    begin
                        input_direction = direction; //Read in inputs every clock cycle
                        input_player = player;
                        input_row = row;
                        input_col = col;
                        size = 3'b0;                 //Reset bools and counters
                        valid = 1'b0;
                        finished_ship = 1'b0;
                        all_ships = 1'b0;
                        if (input_player == expected_player) valid = 1'b1;
                        else valid = 1'b0;  //Set the valid variable
                    end
                ON_BOARD_SET:
                    begin       //Check that it fits if it is horizontal
                        if (input_direction && input_row < 4'd10 && input_col < (10-ship_sizes[ship_addr[input_player]])) 
                            begin
                                valid = 1'b1;
                                row_addr[input_player] = input_row;
                                col_addr[input_player] = input_col;
                            end  //Check that if fits if it is vertical
                        else if (~input_direction && input_col < 4'd10 && input_row < (10-ship_sizes[ship_addr[input_player]])) 
                            begin
                                valid = 1'b1;
                                row_addr[input_player] = input_row;
                                col_addr[input_player] = input_col;
                            end
                        else 
                            begin
                                valid = 1'b0; //It doesn't fits
                                //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT
                                // data_out = {cell, row, col, player, sink};
                                data_out = {2'b01, row_addr[~input_player], col_addr[~input_player],
                                            ~input_player, 1'b0};
                            end
                    end
                CHECK_CELLS:
                    begin   
                        if (read_data[input_player] != 2'b00) //The cell is not empty
                            begin                             // Can stop checking
                                valid = 1'b0;            // Reset variables
                                finished_ship = 1'b1;
                                //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT
                                // data_out = {cell, row, col, player, sink}; 
                                data_out = {2'b01, row_addr[~input_player], col_addr[~input_player],
                                            ~input_player, 1'b0};
                            end
                        else if (size == ship_sizes[ship_addr[input_player]] - 1'b1) //Reached the end of the ship
                            begin
                                size = 3'b000; //Reset size for SET_SHIP_POS
                                finished_ship = 1'b1;      //The ship should be placed
                                write_enable[input_player] = 1'b1;
                                write_enable_ss[input_player] = 1'b1;
                                write_data[input_player] = 2'b11;
                                write_data_ss[input_player] = {input_row, input_col, input_direction};
                                row_addr[input_player] = input_row; //Reset row and col after incrementing
                                col_addr[input_player] = input_col;
                            end
                        else
                            begin                       //Otherwise move on to the next cell of the ship
                                size = size + 1'b1;
                                // horizontal
                                if (input_direction) col_addr[input_player] = col_addr[input_player] + 1'b1;
                                // vertical
                                else                 row_addr[input_player] = row_addr[input_player] + 1'b1;
                            end
                    end
                SET_SHIP_POS:
                    begin               //Write the ship info into Ship Storage
                        write_enable_ss[input_player] = 1'b0;  //Disable writing
                        // data_out = {cell, row, col, player, sink}
                        data_out = {2'b11, row_addr[input_player], col_addr[input_player],
                                            input_player, 1'b0};
                        if (size == ship_sizes[ship_addr[input_player]] - 1'b1) //Reached the end of the ship
                            begin
                                finished_ship = 1'b0;
                                size = 3'b0;
                                write_enable[input_player] = 1'b0;
                                write_data[input_player] = 2'b00;
                                if (ship_addr[input_player] == 3'b100) 
                                    begin
                                        all_ships = 1'b1;
                                        expected_player = 1'b1; //If all ships have been inputted
                                    end
                                else ship_addr[input_player] = ship_addr[input_player] + 1'b1;  //Move on to next ship
                            end                                                                 //Change to next player
                        else if (finished_ship)
                            begin                       //Not at the end of the ship, move on to next cell
                                size = size + 1'b1;
                                // horizontal
                                if (input_direction) col_addr[input_player] = col_addr[input_player] + 1'b1;
                                // vertical
                                else                 row_addr[input_player] = row_addr[input_player] + 1'b1;

                            end    
                    end
                GAME_START: expected_player = 1'b0;        //Start with player 1
                LOAD_SHOT_DATA:
                    begin
                        input_direction = direction;      //Read inputs on clock edge
                        input_player = player;
                        input_row = row;
                        input_col = col;
                        size = 3'b0;
                        valid = 1'b0;
                        finished_ship = 1'b0;
                        all_ships = 1'b0;
                        if (input_player == expected_player) valid = 1'b1;    //Set valid
                        else valid = 1'b0;
                    end
                CHECK_PLAYER2:
                    begin
                        //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT
                        // data_out = {cell, row, col, player, sink}; 
                        if (~valid) data_out = {2'b01, row_addr[~input_player], col_addr[~input_player],
                                                ~input_player, 1'b0};
                    end
                ON_BOARD_SET2:
                    begin
                        if (input_row < 3'd10 && input_col < 3'd10)     //Check if the desired cell is on the board
                            begin
                                valid = 1'b1;
                                row_addr[input_player] = input_row;
                                col_addr[input_player] = input_col;
                            end
                        else 
                            begin
                                valid = 1'b0; //It doesn't fit
                                //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT
                                // data_out = {cell, row, col, player, sink}; 
                                data_out = {2'b01, row_addr[~input_player], col_addr[~input_player],
                                            ~input_player, 1'b0};
                            end
                    end
                CHECK_SHOT_VALID:
                    begin
                        if (read_data[~input_player] == 2'b00)      //The cell is empty
                            begin
                                valid = 1'b1;
                                hit = 1'b0;
                                write_enable[~input_player] = 1'b1;
                                write_data[~input_player] = 2'b01; //Mark the miss, disable writing, and switch players
                            end
                        else if (read_data[~input_player] == 2'b11)     // The cell is a ship
                            begin
                                valid = 1'b1;
                                hit = 1'b1;
                                write_enable[~input_player] = 1'b1;
                                write_data[~input_player] = 2'b10;    //Mark the hit and disable writing
                            end
                        else                                    //The cell has already be shot at
                            begin
                                valid = 1'b0;
                                 //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT
                                // data_out = {cell, row, col, player, sink};
                                data_out = {2'b01, row_addr[~input_player], col_addr[~input_player],
                                            ~input_player, 1'b0};
                            end
                    end
                MARK_SHOT:
                    begin
                        expected_player = ~expected_player;
                        if (hit) //Hit
                            begin
                                write_enable[~input_player] = 1'b0;
                                ship_addr[~input_player] = 3'b000;    //Set up variables for checking if ships are sunk           
                                sunk_count_old[~input_player] = sunk_count[~input_player];
                                sunk_count[~input_player] = 3'b000;
                            end
                        else        //Miss
                            begin     
                                write_enable[~input_player] = 1'b0;
                                //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT
                                // data_out = {cell, row, col, player, sink}; 
                                data_out = {2'b01, row_addr[~input_player], col_addr[~input_player],
                                            ~input_player, 1'b0};
                            end
                    end
                GET_SHIP_INFO:
                    begin           //Get the info for the ship from Ship Storage
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_data[~input_player] = 2'b00;
                        write_enable[~input_player] = 1'b0;
                        {row_addr[~input_player], col_addr[~input_player], input_direction} = read_data_ss[~input_player];
                    end
                CHECK_SUNK:
                    begin
                        if (read_data[~input_player] == 2'b11) //if it is a ship
                            begin
                                finished_ship = 1'b1;
                                size = 3'b0;
                                if (ship_addr[~input_player] == 3'b100) 
                                    begin
                                        all_ships = 1'b1;
                                    end
                                else ship_addr[~input_player] = ship_addr[~input_player] + 1'b1;
                            end
                        else if (size == ship_sizes[ship_addr[~input_player]]-1'b1)
                            begin
                                finished_ship = 1'b1;
                                size = 3'b0;
                                ship_addr[~input_player] = ship_addr[~input_player] + 1'b1;
                                sunk_count[~input_player] = sunk_count[~input_player] + 1'b1;
                                if (ship_addr[~input_player] == 3'b100) 
                                    begin
                                        all_ships = 1'b1;
                                    end
                                else ship_addr[~input_player] = ship_addr[~input_player] + 1'b1;
                            end
                        else if (~finished_ship)
                            begin
                                size = size + 1'b1;
                                // horizontal
                                if (input_direction) col_addr[~input_player] = col_addr[~input_player] + 1'b1;
                                // vertical
                                else                 row_addr[~input_player] = row_addr[~input_player] + 1'b1;
                            end
                    end
                CHECK_ALL_SUNK:
                    begin
                        if (sunk_count[~input_player] != sunk_count_old[~input_player]) 
                                // data_out = {cell, row, col, player, sink};
                                data_out = {2'b10, row_addr[~input_player], col_addr[~input_player],
                                            ~input_player, 1'b1};
                        else    data_out = {2'b10, row_addr[~input_player], col_addr[~input_player],
                                            ~input_player, 1'b0};
                    end
                GAME_OVER:
                    begin
                        // input_player has won
                        // data_out = {cell, row, col, player, sink};
                        data_out = {2'b01, 4'b1111, 4'b1111, input_player, 1'b0};
                    end
                DATA_SETUP: data_ready = 1'b1;
                DATA_SEND: data_ready = 1'b0;       
                default: expected_player <= 1'b0;
            endcase
        end
endmodule


//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: Game Board Memory
// Summary: The module for the game board memory
//------------------------------------------------
module gb_mem(input logic ph2, reset, write_enable,
              input logic [3:0] row, col,
              input logic [3:0] write_data,
              output logic [1:0] read_data);
    // write_data:
    // 00 -> nothing, lights off
    // 01 -> miss, blue light
    // 10 -> hit, red light
    // 11 -> ship, green light

    // mem is 10 chunks x 10 chunks, 100 places to store
    // 2 bits per memory location

    logic [1:0] mem[9:0][9:0]; //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% FIX LATER
    assign read_data = mem[row][col];
    always_latch
        begin
            if (reset)
                begin
                    for (i=0; i<8; i=i+1) mem[i] <= 2'b00;
                end
            else (write_enable & ph2) mem[row][col] <= write_data;
        end
endmodule


//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: Ship Storage Memory
// Summary: The module for the ship storage memory
//------------------------------------------------
module ss_mem(input logic ph2, reset, write_enable,
              input logic [2:0] ship_addr,
              input logic [8:0] write_data,
              output logic [8:0] read_data);
    // write_data:

    // mem is 5 chunks, 5 places to store ship data
    // 9 bits per memory location
    logic [8:0] mem[4:0];
    assign read_data = mem[ship_addr];
    always_latch
        begin
            if (reset)
                begin
                    for (i=0; i<8; i=i+1) mem[i] <= 9'b0;
                end
            else (write_enable & ph2) mem[ship_addr] <= write_data;
        end
endmodule


module latch #(parameter WIDTH = 8)
                (input logic ph,
                 input logic [WIDTH-1:0] d,
                 output logic [WIDTH-1:0] q);

    always_latch
        if (ph) q <= d;

endmodule

module flopenr #(parameter WIDTH = 8)
                (input logic ph1, ph2, reset, en,
                 input logic [WIDTH-1:0] d,
                 output logic [WIDTH-1:0] q);

    logic [WIDTH-1:0] d2, resetval;

    assign resetval = 0;

    mux3 #(WIDTH) enrmux(q, d, resetval, {reset, en}, d2);
    flop #(WIDTH) f(ph1, ph2, d2, q);

endmodule

module flop #(parameter WIDTH = 8)
             (input logic ph1, ph2,
              input logic [WIDTH-1:0] d,
              output logic [WIDTH-1:0] q);
     logic [WIDTH-1:0] mid;

     latch #(WIDTH) master(ph2, d, mid);
     latch #(WIDTH) slave(ph1, mid, q);

endmodule

module flopen #(parameter WIDTH = 8)
               (input logic ph1, ph2, en,
                input logic [WIDTH-1:0] d,
                output logic [WIDTH-1:0] q);

     logic [WIDTH-1:0] d2;

     mux2 #(WIDTH) enmux(q, d, en, d2);
     flop #(WIDTH) f(ph1, ph2, d2, q);

endmodule

module mux3 #(parameter WIDTH = 8)
             (input logic [WIDTH-1:0] d0, d1, d2,
              input logic [1:0] s,
              output logic [WIDTH-1:0] y);

    always_comb
        casez (s)
            2'b00: y = d0;
            2'b01: y = d1;
            2'b1?: y = d2;
        endcase

endmodule

module mux_2_1 #(parameter width=1)
                (input logic [width-1:0] A,
                 input logic [width-1:0] B,
                 input logic ctrl,
                 output logic [width-1:0] out);

    always_comb
        if (ctrl) out <= A;
        else out <= B;

endmodule

module mux2 #(parameter WIDTH = 8)
             (input logic [WIDTH-1:0] d0, d1,
              input logic s,
              output logic [WIDTH-1:0] y);

 assign y = s ? d1 : d0;

endmodule



