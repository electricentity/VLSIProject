//------------------------------------------------
// battleship.sv
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
//------------------------------------------------

// TO DO: testbench, proofread logic, comment heavily, Get comb/seq logic working


//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: Controller (FSM)
// Summary: The module for the controller/fsm
// TO DO: Finish all submodules and compatibility.
//------------------------------------------------
module battleship(input logic ph1, ph2, reset, read, player, direction,
	              input logic [3:0] row, col,
                  output logic [11:0] data_out,
                  output logic data_ready);

    logic       write_enable[1:0];
    logic [1:0] write_data[1:0], read_data[1:0];
    logic [3:0] row_addr[1:0]; // 10 rows required
    logic [3:0] col_addr[1:0]; // 10 columns required
    logic        write_enable_ss[1:0];
    logic [11:0] write_data_ss[1:0], read_data_ss[1:0];
    logic [2:0] ship_addr[1:0];


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

    // Instantiate the SPI module
    // spi s(sclk, sdi, done, data, sdo);

endmodule


//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: Controller (FSM)
// Summary: The module for the controller/fsm
// TO DO: Flesh out all states, write the logic for all states.
//------------------------------------------------
module controller(input logic ph1, ph2, reset, read, player, direction,
                  input logic [3:0] row, col,
                  input logic [1:0] read_data[1:0],
                  input logic [11:0] read_data_ss[1:0],
                  output logic [1:0] write_data[1:0],
                  output logic [11:0] write_data_ss[1:0], 
                  output logic [3:0] row_addr[1:0], col_addr[1:0],
                  output logic [2:0] ship_addr[1:0],
                  output logic write_enable[1:0], write_enable_ss[1:0], data_ready,
                  output logic [11:0] data_out);
    
    logic pos_valid, shot_valid, expected_player, finished_ship, hit, all_ships;
    logic input_player, input_direction, data_player, data_sink, correct_player;
    logic ship_dir;
    logic [1:0] data_cell;
    logic [2:0] size, ship_len; // counter
    logic [2:0] sunk_count[1:0], sunk_count_old[1:0];
    logic [3:0] input_row, input_col, data_row, data_col;
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
                INITIAL_START:
                    begin
                        nextstate = LOAD_SHIP_DATA;
                    end
                // Load in player inputs and save them, reset some values, set correct_player
                LOAD_SHIP_DATA:
                    begin
                        if (read) nextstate = CHECK_PLAYER;
                        else      nextstate = LOAD_SHIP_DATA;
                    end
                // Check that the correct player in inputting
                CHECK_PLAYER:
                    begin
                        if (correct_player) nextstate = ON_BOARD_SET;
                        else                nextstate = LOAD_SHIP_DATA;
                    end
                // Check if ship placement would be out of bounds or not, set pos_valid
                ON_BOARD_SET:
                    begin
                        nextstate = ON_BOARD_CHECK;
                    end
                // If pos_valid is set to 1 above, go to check cells. Else, get new inputs
                ON_BOARD_CHECK:
                    begin
                        if (pos_valid) nextstate = CHECK_CELLS;
                        else
                            begin
                                       nextstate = DATA_SETUP;
                            end
                    end
                // After checking all cells ship could be on, determine whether or not
                // to set the ship there (are there any collisions with other ships)
                CHECK_CELLS:
                    begin
                        if (finished_ship)
                            begin
                                if (pos_valid) nextstate = SET_SHIP_POS;
                                else           
                                    begin
                                               nextstate = DATA_SETUP;
                                    end
                            end
                        else                   nextstate = CHECK_CELLS;
                    end
                // If above checks work correctly, place the ship on the board
                // Change expected inputs to next ship or next player accordingly
                SET_SHIP_POS:
                    begin
                        if (~finished_ship)
                            begin
                                if (all_ships) nextstate = GAME_START;
                                else                         nextstate = LOAD_SHIP_DATA;
                            end
                        else                                 
                            begin
                                nextstate = DATA_SETUP;
                            end
                    end
                // Load other stuff; This is a transition state. Reset any values
                GAME_START:
                    begin
                        nextstate = LOAD_SHOT_DATA;
                    end
                // State will handle player inputs, set correct_player
                LOAD_SHOT_DATA:
                    begin
                        if (read) nextstate = CHECK_PLAYER2;
                        else      nextstate = LOAD_SHOT_DATA;
                    end
                // If the player is correct check the board, otherwise ask for new inputs
                CHECK_PLAYER2:
                    begin
                        if (correct_player) nextstate = ON_BOARD_SET2;
                        else 
                            begin
                                            nextstate = DATA_SETUP;
                            end
                    end
                // Check if ship placement would be out of bounds or not, set pos_valid
                ON_BOARD_SET2:
                    begin
                        nextstate = ON_BOARD_CHECK2;
                    end
                // If pos_valid is set to 1 above, go to check cells. Else, rerun the inputs
                ON_BOARD_CHECK2:
                    begin
                        if (pos_valid) nextstate = CHECK_SHOT_VALID;
                        else          
                            begin
                                       nextstate = DATA_SETUP;
                            end
                    end
                // Check if the shot is valid; IE shot in bounds, not shot already, set shot_valid
                // Also set hit and enable writing to desired board
                CHECK_SHOT_VALID:
                    begin
                        nextstate = CHECK_SHOT_VALID2;
                    end
                // Check shot_valid and move on or ask for new inputs 
                CHECK_SHOT_VALID2:
                    begin
                        if (shot_valid) nextstate = MARK_SHOT;
                        else
                            begin
                                        nextstate = DATA_SETUP;
                            end
                    end
                // Save shot, if hit go to CHECK_SUNK, else go to LOAD_SHOT_DATA
                MARK_SHOT:
                    begin
                        if (hit) nextstate = GET_SHIP_INFO;
                        else     
                            begin
                                 nextstate = DATA_SETUP;
                            end
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
                        if (sunk_count[~input_player] == 3'b101) 
                            begin
                                nextstate = DATA_SETUP;
                            end
                        else 
                            begin
                                nextstate = DATA_SETUP;
                            end
                    end
                // Game over, someone won
                GAME_OVER:
                    begin
                        nextstate = GAME_OVER;
                    end
                DATA_SETUP:
                    begin
                        nextstate = DATA_SEND;
                    end
                DATA_SEND:
                    begin
                        nextstate = hold_nextstate;
                    end
                default: nextstate = INITIAL_START;
            endcase
        end

    // nextstate logic
    always_comb
        begin
            case(state)
                // If pos_valid is set to 1 above, go to check cells. Else, get new inputs
                ON_BOARD_CHECK:
                    begin
                        hold_nextstate = LOAD_SHIP_DATA;
                    end
                // After checking all cells ship could be on, determine whether or not
                // to set the ship there (are there any collisions with other ships)
                CHECK_CELLS:
                    begin
                        hold_nextstate = LOAD_SHIP_DATA;
                    end
                // If above checks work correctly, place the ship on the board
                // Change expected inputs to next ship or next player accordingly
                SET_SHIP_POS:
                    begin
                        hold_nextstate = SET_SHIP_POS;
                    end
                CHECK_PLAYER2:
                    begin
                        hold_nextstate = LOAD_SHIP_DATA;
                    end
                // If pos_valid is set to 1 above, go to check cells. Else, rerun the inputs
                ON_BOARD_CHECK2:
                    begin
                        hold_nextstate = LOAD_SHIP_DATA;
                    end
                // Check shot_valid and move on or ask for new inputs 
                CHECK_SHOT_VALID2:
                    begin
                        hold_nextstate = LOAD_SHIP_DATA;
                    end
                // Save shot, if hit go to CHECK_SUNK, else go to LOAD_SHOT_DATA
                MARK_SHOT:
                    begin
                                 hold_nextstate = LOAD_SHOT_DATA;
                    end
                CHECK_ALL_SUNK:
                    begin
                        if (sunk_count[~input_player] == 3'b101) 
                            begin
                                hold_nextstate = GAME_OVER;
                            end
                        else hold_nextstate = LOAD_SHOT_DATA;
                    end
                default:
                    hold_nextstate = INITIAL_START;
            endcase
        end

    // control signal logic
    always_comb
        begin
            case(state)
                INITIAL_START:
                    begin
                    /*
                        ship_sizes[0] = 3'd5;
                        ship_sizes[1] = 3'd4;
                        ship_sizes[2] = 3'd3;
                        ship_sizes[3] = 3'd3;
                        ship_sizes[4] = 3'd2; */
                        expected_player = 1'b0; //Start with player 1
                    end
                LOAD_SHIP_DATA:
                    begin
                        input_direction = direction; //Read in inputs every clock cycle
                        input_player = player;
                        input_row = row;
                        input_col = col;
                        size = 3'b0;                 //Reset bools and counters
                        pos_valid = 1'b0;
                        finished_ship = 1'b0;
                        all_ships = 1'b0;
                        if (input_player == expected_player) correct_player = 1'b1;
                        else correct_player = 1'b0;  //Set the correct_player variable
                    end
                ON_BOARD_SET:
                    begin       //Check that it fits if it is horizontal
                        if (input_direction && input_row < 4'd10 && input_col < (10-ship_sizes[ship_addr[input_player]])) 
                            begin
                                pos_valid = 1'b1;
                                row_addr[input_player] = input_row;
                                col_addr[input_player] = input_col;
                            end  //Check that if fits if it is vertical
                        else if (~input_direction && input_col < 4'd10 && input_row < (10-ship_sizes[ship_addr[input_player]])) 
                            begin
                                pos_valid = 1'b1;
                                row_addr[input_player] = input_row;
                                col_addr[input_player] = input_col;
                            end
                        else 
                            begin
                                pos_valid = 1'b0; //It doesn't fits        
                                data_cell = 2'b01;
                                data_row = row_addr[~input_player];        //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT
                                data_col = col_addr[~input_player];
                                data_player = ~input_player;
                                data_sink = 1'b0;
                            end
                    end
                CHECK_CELLS:
                    begin   
                        if (read_data[input_player] != 2'b00) //The cell is not empty
                            begin                             // Can stop checking
                                pos_valid = 1'b0;            // Reset variables
                                finished_ship = 1'b1;
                                data_cell = 2'b01;     //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT
                                data_row = row_addr[~input_player];
                                data_col = col_addr[~input_player];
                                data_player = ~input_player;
                                data_sink = 1'b0;
                            end
                        else if (size == ship_sizes[ship_addr[input_player]]) //Reached the end of the ship
                            begin
                                size = 3'b0; //Reset size for SET_SHIP_POS
                                finished_ship = 1'b1;      //The ship should be placed
                                write_enable[input_player] = 1'b1;
                                write_enable_ss[input_player] = 1'b1;
                                write_data[input_player] = 2'b11;
                                write_data_ss[input_player] = {row, col, direction, ship_sizes[ship_addr[input_player]]};
                                row_addr[input_player] = input_row; //Reset row and col after incrementing
                                col_addr[input_player] = input_col;
                            end
                        else
                            begin                       //Otherwise move on to the next cell of the ship
                                size = size + 1'b1;
                                if (input_direction) // horizontal
                                    begin
                                        col_addr[input_player] = col_addr[input_player] + 1'b1;
                                    end
                                else // vertical
                                    begin
                                        row_addr[input_player] = row_addr[input_player] + 1'b1;
                                    end
                            end
                    end
                SET_SHIP_POS:
                    begin               //Write the ship info into Ship Storage
                        write_enable_ss[input_player] = 1'b0;  //Disable writing
                        //write_data[input_player] = 2'b11;      //Mark the cell as a ship
                        data_cell = 2'b11;   
                        data_row = row_addr[input_player];
                        data_col = col_addr[input_player];
                        data_player = input_player;
                        data_sink = 1'b0;
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
                                if (input_direction) // horizontal
                                    begin
                                        col_addr[input_player] = col_addr[input_player] + 1'b1;
                                    end
                                else // vertical
                                    begin
                                        row_addr[input_player] = row_addr[input_player] + 1'b1;
                                    end
                            end    
                    end
                GAME_START:
                    begin
                        expected_player = 1'b0;        //Start with player 1
                    end
                LOAD_SHOT_DATA:
                    begin
                        input_direction = direction;      //Read inputs on clock edge
                        input_player = player;
                        input_row = row;
                        input_col = col;
                        size = 3'b0;
                        shot_valid = 1'b0;
                        pos_valid = 1'b0;
                        finished_ship = 1'b0;
                        all_ships = 1'b0;
                        if (input_player == expected_player) correct_player = 1'b1;    //Set correct_player
                        else correct_player = 1'b0;
                    end
                CHECK_PLAYER2:
                    begin
                        if (~correct_player) 
                            begin //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT                                
                                data_cell = 2'b01;
                                data_row = row_addr[~input_player];
                                data_col = col_addr[~input_player];
                                data_player = ~input_player;
                                data_sink = 1'b0;
                            end    
                    end
                ON_BOARD_SET2:
                    begin
                        if (input_row < 3'd10 && input_col < 3'd10)     //Check if the desired cell is on the board
                            begin
                                pos_valid = 1'b1;
                                row_addr[input_player] = input_row;
                                col_addr[input_player] = input_col;
                            end
                        else 
                            begin //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT
                                pos_valid = 1'b0; //It doesn't fit
                                data_cell = 2'b01;
                                data_row = row_addr[~input_player];
                                data_col = col_addr[~input_player];
                                data_player = ~input_player;
                                data_sink = 1'b0;
                            end
                    end
                CHECK_SHOT_VALID:
                    begin
                        if (read_data[~input_player] == 2'b00)      //The cell is empty
                            begin
                                shot_valid = 1'b1;
                                hit = 1'b0;
                                write_enable[~input_player] = 1'b1;
                                write_data[~input_player] = 2'b01; //Mark the miss, disable writing, and switch players
                            end
                        else if (read_data[~input_player] == 2'b11)     // The cell is a ship
                            begin
                                shot_valid = 1'b1;
                                hit = 1'b1;
                                write_enable[~input_player] = 1'b1;
                                write_data[~input_player] = 2'b10;    //Mark the hit and disable writing
                            end
                        else                                    //The cell has already be shot at
                            begin
                                shot_valid = 1'b0;
                                data_cell = 2'b01;     //%%%%%%%%%%%%%%%%%%%%%%%% NEED TO UPDATE OUTPUT
                                data_row = row_addr[~input_player];
                                data_col = col_addr[~input_player];
                                data_player = ~input_player;
                                data_sink = 1'b0;
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
                                data_cell = 2'b01;
                                data_row = row_addr[~input_player];
                                data_col = col_addr[~input_player];
                                data_player = ~input_player;
                                data_sink = 1'b0;
                            end
                    end
                GET_SHIP_INFO:
                    begin           //Get the info for the ship from Ship Storage
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_data[~input_player] = 2'b00;
                        write_enable[~input_player] = 1'b0;
                        {row_addr[~input_player], col_addr[~input_player], ship_dir, ship_len} = read_data_ss[~input_player];
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
                        else if (size == ship_len-1'b1)
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
                                if (ship_dir) // horizontal
                                    begin
                                        col_addr[~input_player] = col_addr[~input_player] + 1'b1;
                                    end
                                else // vertical
                                    begin
                                        row_addr[~input_player] = row_addr[~input_player] + 1'b1;
                                    end
                            end
                    end
                CHECK_ALL_SUNK:
                    begin
                        if (sunk_count[~input_player] != sunk_count_old[~input_player]) 
                            begin
                                data_cell = 2'b10;
                                data_row = row_addr[~input_player];
                                data_col = col_addr[~input_player];
                                data_player = ~input_player;
                                data_sink = 1'b1;
                            end
                        else
                            begin
                                data_cell = 2'b10;
                                data_row = row_addr[~input_player];
                                data_col = col_addr[~input_player];
                                data_player = ~input_player;
                                data_sink = 1'b0;
                            end
                    end
                GAME_OVER:
                    begin
                        row_addr[player] = 4'b0000;
                        data_cell = 2'b01;
                        data_row = 4'b1111;
                        data_col = 4'b1111;
                        data_player = input_player;  //This player won
                        data_sink = 1'b0;
                    end
                DATA_SETUP:
                    begin
                        data_out = {data_cell, data_row, data_col, data_player, data_sink};
                        data_ready = 1'b1;
                    end
                DATA_SEND:
                    begin
                        data_ready = 1'b0;
                    end           
                default:
                    begin
                        row_addr[player] = 4'b0000;
                    end
            endcase
        end
endmodule


//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: Game Board Memory
// Summary: The module for the game board memory
// TO DO: Change as required for the controller/fsm.
//------------------------------------------------
module gb_mem(input logic clk, reset, write_enable,
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
    logic [1:0] mem[9:0][9:0];
    always_ff @(posedge clk) begin
        if (reset) mem <= 0; // THIS MIGHT BE A PROBLEM LATER
        if (write_enable) mem[row][col] <= write_data;
        assign read_data = mem[row][col];
    // assign read_data = mem[row][col];
    // this is read-after-write
    // put read_data <= mem[address] in always_ff block
    // for read before write
    end

endmodule


//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: Ship Storage Memory
// Summary: The module for the ship storage memory
// TO DO: Change as required for the controller/fsm.
//------------------------------------------------
module ss_mem(input logic clk, reset, write_enable,
              input logic [2:0] ship_addr,
              input logic [11:0] write_data,
              output logic [11:0] read_data);
    // write_data:

    // mem is 5 chunks, 5 places to store ship data
    // 13 bits per memory location
    logic [11:0] mem[4:0];
    always_ff @(posedge clk) begin
        if (reset) mem <= 0; // THIS MIGHT BE A PROBLEM LATER
        if (write_enable) mem[ship_addr] <= write_data;
        assign read_data = mem[ship_addr];
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


/*
//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: SPI
// Summary: The module for spi, modified from the E155 version
// TO DO: Change to match our controller/fsm.
//------------------------------------------------
module spi(input  logic sck, done,
           input  logic [11:0] data,
           output logic sdo);

    logic        sdodelayed, wasdone;
    logic [11:0] data_captured;
               
    // wait until done
    // then apply 12 sclks to shift out data, starting with data[0]

    always_ff @(posedge sck)
        if (!wasdone)  data_captured <= data;
        else           data_captured <= {data_captured[10:0], 1'b0}; 
    end    
    // sdo should change on the negative edge of sck
    always_ff @(negedge sck) begin
        wasdone <= done;
        sdodelayed <= data_captured[10];
    end
    
    // when done is first asserted, shift out msb before clock edge
    assign sdo = (done & !wasdone) ? data[11] : sdodelayed;
endmodule

*/

