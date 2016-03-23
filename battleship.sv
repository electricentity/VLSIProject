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
    logic [1:0] write_data, read_data[1:0];
    logic [2:0] ship_addr;
    logic [3:0] row_addr, col_addr; // 10 rows/columns required
    logic [8:0] write_data_ss, read_data_ss[1:0];

    // Instantiate the FSM controller for the system
    controller c(ph1, ph2, reset, read, player, direction,
                 row, col, read_data, read_data_ss,
                 write_data, write_data_ss, 
                 row_addr, col_addr, ship_addr,
                 write_enable, write_enable_ss,
                 data_ready, data_out);

    // Instantiate the memory block for the system
    gb_mem gameboard1(ph2, reset, write_enable[0],
                      row_addr, col_addr, write_data, read_data[0]);

    gb_mem gameboard2(ph2, reset, write_enable[1],
                      row_addr, col_addr, write_data, read_data[1]);

    ss_mem shipstorage1(ph2, reset, write_enable_ss[0],
                        ship_addr, write_data_ss, read_data_ss[0]);

    ss_mem shipstorage2(ph2, reset, write_enable_ss[1],
                        ship_addr, write_data_ss, read_data_ss[1]);
endmodule


//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: Controller (FSM)
// Summary: The module for the controller/fsm
//------------------------------------------------
module controller(input logic ph1, ph2, reset, read, input_player, input_direction,
                  input logic [3:0] input_row, input_col,
                  input logic [1:0] read_data[1:0],
                  input logic [8:0] read_data_ss[1:0],
                  output logic [1:0] write_data,
                  output logic [8:0] write_data_ss, 
                  output logic [3:0] row_addr, col_addr,
                  output logic [2:0] ship_addr,
                  output logic write_enable[1:0], write_enable_ss[1:0], data_ready,
                  output logic [11:0] data_out);
    
    logic valid, expected_player, finished_ship, hit, all_ships;
    logic player, direction;
    logic [2:0] size; // counter
    logic [3:0] row, col;
    logic [2:0] sunk_count, sunk_count_old[1:0];
    logic [4:0] state, nextstate, hold_nextstate;
    logic [2:0] ship_sizes[4:0] = '{3'b101, 3'b100, 3'b011, 3'b011, 3'b010};

    //holds
    logic player_next, direction_next, expected_player_next;
    logic [2:0] size_next, ship_addr_next; // counter
    logic [3:0] row_next, col_next, row_addr_set, col_addr_set;
    logic [3:0] row_addr_next, col_addr_next;
    logic [2:0] sunk_count_next, sunk_count_old_next[1:0];

    //enables
    logic player_en, direction_en, expected_player_en;
    logic size_en, ship_addr_en; // counter
    logic row_en, col_en, row_addr_set_en, col_addr_set_en;
    logic row_addr_next_en, col_addr_next_en;
    logic sunk_count_en, sunk_count_old_en[1:0];

    //resets
    logic player_r, direction_r, expected_player_r;
    logic size_r, ship_addr_r; // counter
    logic row_r, col_r, row_addr_set_r, col_addr_set_r;
    logic row_addr_next_r, col_addr_next_r;
    logic sunk_count_r, sunk_count_old_r[1:0];

    //buses
    logic [1:0] player_bus, direction_bus, expected_player_bus;
    logic [1:0] size_bus, ship_addr_bus; // counter
    logic [1:0] row_bus, col_bus, row_addr_set_bus, col_addr_set_bus;
    logic [1:0] row_addr_next_bus, col_addr_next_bus;
    logic [1:0] sunk_count_bus, sunk_count_old_bus[1:0];

    //Break buses
    assign {player_en, player_r} = player_bus;
    assign {direction_en, direction_r} = direction_bus;
    assign {expected_player_en, expected_player_r} = expected_player_bus;
    assign {size_en, size_r} = size_bus;
    assign {ship_addr_en, ship_addr_r} = ship_addr_bus;
    assign {row_en, row_r} = row_bus;
    assign {col_en, col_r} = col_bus;
    assign {row_addr_set_en, row_addr_set_r} = row_addr_set_bus;
    assign {row_addr_next_en, row_addr_next_r} = row_addr_next_bus;
    assign {col_addr_set_en, col_addr_set_r} = col_addr_set_bus;
    assign {col_addr_next_en, col_addr_next_r} = col_addr_next_bus;
    assign {sunk_count_en, sunk_count_r} = sunk_count_bus;
    assign {sunk_count_old_en[0], sunk_count_old_r[0]} = sunk_count_old_bus[0];
    assign {sunk_count_old_en[1], sunk_count_old_r[1]} = sunk_count_old_bus[1];

    flopenr #5 statereg(ph1, ph2, reset, 1'b1, nextstate, state);

    flopenr #1 statereg(ph1, ph2, player_r, player_en, player_next, player);
    flopenr #1 statereg(ph1, ph2, direction_r, direction_en, direction_next, direction);
    flopenr #1 statereg(ph1, ph2, expected_player_r, expected_player_en, expected_player_next, expected_player);
    flopenr #3 statereg(ph1, ph2, size_r, size_en, size_next, size);   
    flopenr #3 statereg(ph1, ph2, ship_addr_r, ship_addr_en, ship_addr_next, ship_addr);
    flopenr #4 statereg(ph1, ph2, row_r, row_en, row_next, row);
    flopenr #4 statereg(ph1, ph2, col_r, col_en, col_next, col);
    flopenr #4 statereg(ph1, ph2, row_addr_set_r, row_addr_set_en, row_addr_set, row_addr_set_stage);
    flopenr #4 statereg(ph1, ph2, row_addr_next_r, row_addr_next_en, row_addr_next, row_addr_next_stage);
    flopenr #4 statereg(ph1, ph2, col_addr_set_r, col_addr_set_en, col_addr_set, col_addr_set_stage);
    flopenr #4 statereg(ph1, ph2, col_addr_next_r, col_addr_next_en, col_addr_next, col_addr_next_stage);
    flopenr #3 statereg(ph1, ph2, sunk_count_r, sunk_count_en, sunk_count_next, sunk_count);
    flopenr #4 statereg(ph1, ph2, sunk_count_old_r[0], sunk_count_old_en[0], sunk_count_old_next[0], sunk_count_old[0]);
    flopenr #4 statereg(ph1, ph2, sunk_count_old_r[1], sunk_count_old_en[1], sunk_count_old_next[1], sunk_count_old[1]);

    assign row_addr = row_addr_set_en ? (hit ? read_data_ss[~player][8:5] : row_addr_set_stage) : row_addr_next_stage;
    assign col_addr = col_addr_set_en ? (hit ? read_data_ss[~player][4:1] : col_addr_set_stage : col_addr_next_stage;
    assign player_next = input_player;
    assign direction_next = hit ? read_data_ss[~player][0] : input_direction;
    assign expected_player_next = ~expected_player;
    assign size_next = size;
    assign ship_addr_next = ship_addr;
    assign row_next = input_row;
    assign col_next = input_col;
    assign row_addr_set = row;
    assign row_addr_next = row_addr + 1'b1;
    assign col_addr_set = col;
    assign col_addr_next = col_addr + 1'b1;
    assign sunk_count_next = sunk_count + 1'b1;
    assign sunk_count_old_next[0] = sunk_count;
    assign sunk_count_old_next[1] = sunk_count;

    // GLOBAL VARIABLES
    parameter RESET = 2'b01;
    parameter ENABLE = 2'b10;
    parameter HOLD = 2'b00;

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
                        if (read) 
                            begin
                                if (valid) nextstate = ON_BOARD_SET;
                                else       nextstate = LOAD_SHIP_DATA;
                            end
                        else      nextstate = LOAD_SHIP_DATA;
                    end
                // If valid is set to 1 above, go to check cells. Else, get new inputs
                ON_BOARD_CHECK:
                    begin
                        if (valid) nextstate = CHECK_CELLS;
                        else       nextstate = LOAD_SHIP_DATA;
                    end
                // After checking all cells ship could be on, determine whether or not
                // to set the ship there (are there any collisions with other ships)
                CHECK_CELLS:
                    begin
                        if (finished_ship)
                            begin
                                if (valid) nextstate = SET_SHIP_POS;
                                else       nextstate = LOAD_SHIP_DATA;
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
                        else                   nextstate = SET_SHIP_POS;
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
                GET_SHIP_INFO: nextstate = CHECK_SUNK;
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
                        if (sunk_count[~player] == 3'b101) nextstate = DATA_SETUP;
                        else                                     nextstate = DATA_SETUP;
                    end
                // Game over, someone won
                GAME_OVER: nextstate = DATA_SEND;
                DATA_SETUP: nextstate = DATA_SEND;
                DATA_SEND: nextstate = hold_nextstate;
                default: nextstate = INITIAL_START;
            endcase
        end

    // control signal logic
    always_comb
        begin
            case(state)
                INITIAL_START: 
                    begin
                        hit = 1'b0;
                        valid = 1'b0;
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;
                        data_ready = 1'b0;
                        data_out = 12'b0;

                        player_bus = RESET;
                        direction_bus = RESET;
                        expected_player_bus = RESET;
                        size_bus = RESET;
                        ship_addr_bus = RESET;
                        row_bus = RESET;
                        col_bus = RESET;
                        row_addr_set_bus = RESET;
                        col_addr_set_bus = RESET;
                        row_addr_next_bus = RESET;
                        col_addr_next_bus = RESET;
                        sunk_count_bus = RESET;
                        sunk_count_old_bus[0] = RESET;
                        sunk_count_old_bus[1] = RESET;
                    end 
                LOAD_SHIP_DATA:
                    begin
                        hit = 1'b0;
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;

                        player_bus = ENABLE;
                        direction_bus = ENABLE;
                        expected_player_bus = HOLD;
                        size_bus = RESET;
                        ship_addr_bus = HOLD;
                        row_bus = ENABLE;
                        col_bus = ENABLE;
                        row_addr_set_bus = RESET;
                        col_addr_set_bus = RESET;
                        row_addr_next_bus = RESET;
                        col_addr_next_bus = RESET;
                        sunk_count_bus = RESET;
                        sunk_count_old_bus[0] = RESET;
                        sunk_count_old_bus[1] = RESET;

                        data_out = {2'b10, 4'b1111, 4'b1111, ~player, 1'b0};
                        if (player == expected_player) 
                            begin
                                data_ready = 1'b0;
                                valid = 1'b1;
                            end
                        else 
                            begin
                                data_ready = 1'b1;
                                valid = 1'b0;  //Set the valid variable
                            end
                    end
                ON_BOARD_CHECK:
                    begin
                        hit = 1'b0;
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;

                        player_bus = HOLD;
                        direction_bus = HOLD;
                        expected_player_bus = HOLD;
                        size_bus = RESET;
                        ship_addr_bus = HOLD;
                        row_bus = HOLD;
                        col_bus = HOLD;
                        row_addr_next_bus = HOLD;
                        col_addr_next_bus = HOLD;
                        row_addr_set_bus = ENABLE;
                        col_addr_set_bus = ENABLE;
                        sunk_count_bus = RESET;
                        sunk_count_old_bus[0] = RESET;
                        sunk_count_old_bus[1] = RESET;

                        if (direction && row < 4'd10 && col < (10-ship_sizes[ship_addr]))  //Check that it fits if it is horizontal
                            begin
                                valid = 1'b1;
                                data_ready = 1'b0;
                                data_out = 12'b0;
                            end  //Check that if fits if it is vertical
                        else if (~direction && col < 4'd10 && row < (10-ship_sizes[ship_addr])) 
                            begin
                                valid = 1'b1;
                                data_ready = 1'b0;
                                data_out = 12'b0;
                            end
                        else 
                            begin
                                valid = 1'b0;
                                data_ready = 1'b1;
                                data_out = {2'b11, 4'b1111, 4'b1111, player, 1'b0};
                            end
                    end
                CHECK_CELLS:
                    begin   
                        hit = 1'b0;
                        all_ships = 1'b0;
                        write_enable[~player] = 1'b0;
                        write_enable_ss[~player] = 1'b0;

                        player_bus = HOLD;
                        direction_bus = HOLD;
                        expected_player_bus = HOLD;
                        ship_addr_bus = HOLD;
                        row_bus = HOLD;
                        col_bus = HOLD;
                        sunk_count_bus = RESET;
                        sunk_count_old_bus[0] = RESET;
                        sunk_count_old_bus[1] = RESET;
                        if (read_data[player] != 2'b00) //The cell is not empty
                            begin                             // Can stop checking
                                valid = 1'b0;            // Reset variables
                                finished_ship = 1'b1;
                                write_data = 2'b00;
                                write_enable[player] = 1'b0;
                                write_data_ss = 9'b0;
                                write_enable_ss[player] = 1'b0;
                                data_ready = 1'b1;
                                data_out = {2'b11, 4'b1111, 4'b1111, player, 1'b0};

                                size_bus = RESET;
                                row_addr_set_bus = HOLD;
                                col_addr_set_bus = HOLD;
                                row_addr_next_bus = HOLD;
                                col_addr_next_bus = HOLD;
                            end
                        else if (size == ship_sizes[ship_addr] - 1'b1) //Reached the end of the ship
                            begin
                                valid = 1'b1;
                                finished_ship = 1'b1;
                                write_enable[player] = 1'b1;
                                write_enable_ss[player] = 1'b1;
                                write_data = 2'b11;
                                write_data_ss = {row, col, direction};
                                data_ready = 1'b0;
                                data_out = 12'b0;

                                size_bus = RESET;
                                row_addr_set_bus = ENABLE;
                                col_addr_set_bus = ENABLE;
                                row_addr_next_bus = RESET;
                                col_addr_next_bus = RESET;
                            end
                        else
                            begin                       //Otherwise move on to the next cell of the ship
                                valid = 1'b1;
                                finished_ship = 1'b0;
                                write_data = 2'b00;
                                write_enable[player] = 1'b0;
                                write_data_ss = 9'b0;
                                write_enable_ss[player] = 1'b0;
                                data_ready = 1'b0;
                                data_out = 12'b0;

                                size_bus = ENABLE;
                                row_addr_set_bus = HOLD;
                                col_addr_set_bus = HOLD;
                                // horizontal
                                if (direction) 
                                    begin
                                        row_addr_next_bus = HOLD;
                                        col_addr_next_bus = ENABLE;
                                    end
                                // vertical
                                else
                                    begin
                                        row_addr_next_bus = ENABLE;
                                        col_addr_next_bus = HOLD;
                                    end
                            end
                    end
                SET_SHIP_POS:
                    begin               //Write the ship info into Ship Storage
                        hit = 1'b0;
                        valid = 1'b0;
                        write_enable[~player] = RESET;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;
                        data_ready = 1'b1;

                        player_bus = HOLD;
                        direction_bus = HOLD;
                        row_bus = HOLD;
                        col_bus = HOLD;
                        sunk_count_bus = RESET;
                        sunk_count_old_bus[0] = RESET;
                        sunk_count_old_bus[1] = RESET;

                        // data_out = {cell, row, col, player, sink}
                        data_out = {2'b11, row_addr, col_addr, player, 1'b0};

                        if (size == ship_sizes[ship_addr] - 1'b1) //Reached the end of the ship
                            begin
                                finished_ship = 1'b0;
                                write_enable[player] = 1'b0;
                                write_data = 2'b00;

                                size_bus = RESET;
                                row_addr_set_bus = HOLD;
                                col_addr_set_bus = HOLD;
                                row_addr_next_bus = HOLD;
                                col_addr_next_bus = HOLD;

                                if (ship_addr == 3'b100) 
                                    begin
                                        all_ships = 1'b1;

                                        expected_player_bus = ENABLE;
                                        ship_addr_bus = HOLD;
                                    end
                                else 
                                    begin
                                        all_ships = 1'b0;

                                        expected_player_bus = HOLD;
                                        ship_addr_bus = ENABLE;
                                    end
                            end                                                                 //Change to next player
                        else if (finished_ship)
                            begin                       //Not at the end of the ship, move on to next cell
                                finished_ship = 1'b0;
                                write_enable[player] = 1'b0;
                                write_data = 2'b00;
                                all_ships = 1'b0;

                                expected_player_bus = HOLD;
                                size_bus = ENABLE;
                                ship_addr_bus = HOLD;
                                row_addr_set_bus = HOLD;
                                col_addr_set_bus = HOLD;
                                // horizontal
                                if (direction) 
                                    begin
                                        row_addr_next_bus = HOLD;
                                        col_addr_next_bus = ENABLE;
                                    end
                                // vertical
                                else
                                    begin
                                        row_addr_next_bus = ENABLE;
                                        col_addr_next_bus = HOLD;
                                    end
                            end    
                    end
                GAME_START:
                    begin
                        hit = 1'b0;
                        valid = 1'b0;
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;
                        data_ready = 1'b0;
                        data_out = 12'b0;

                        player_bus = RESET;
                        direction_bus = RESET;
                        expected_player_bus = RESET;
                        size_bus = RESET;
                        ship_addr_bus = RESET;
                        row_bus = RESET;
                        col_bus = RESET;
                        row_addr_set_bus = RESET;
                        col_addr_set_bus = RESET;
                        row_addr_next_bus = RESET;
                        col_addr_next_bus = RESET;
                        sunk_count_bus = RESET;
                        sunk_count_old_bus[0] = RESET;
                        sunk_count_old_bus[1] = RESET;
                    end 
                LOAD_SHOT_DATA:
                    begin
                        hit = 1'b0;
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;

                        player_bus = ENABLE;
                        direction_bus = ENABLE;
                        expected_player_bus = HOLD;
                        size_bus = RESET;
                        ship_addr_bus = HOLD;
                        row_bus = ENABLE;
                        col_bus = ENABLE;
                        row_addr_set_bus = RESET;
                        col_addr_set_bus = RESET;
                        row_addr_next_bus = RESET;
                        col_addr_next_bus = RESET;
                        sunk_count_bus = HOLD;
                        sunk_count_old_bus[0] = HOLD;
                        sunk_count_old_bus[1] = HOLD;

                        data_out = {2'b10, 4'b1111, 4'b1111, ~player, 1'b0};
                        if (player == expected_player) 
                            begin
                                data_ready = 1'b0;
                                valid = 1'b1;
                            end
                        else 
                            begin
                                data_ready = 1'b1;
                                valid = 1'b0;  //Set the valid variable
                            end
                    end
                ON_BOARD_CHECK2:
                    begin
                        hit = 1'b0;
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;

                        player_bus = HOLD;
                        direction_bus = HOLD;
                        expected_player_bus = HOLD;
                        size_bus = RESET;
                        ship_addr_bus = HOLD;
                        row_bus = HOLD;
                        col_bus = HOLD;
                        row_addr_next_bus = HOLD;
                        col_addr_next_bus = HOLD;
                        row_addr_set_bus = ENABLE;
                        col_addr_set_bus = ENABLE;
                        sunk_count_bus = HOLD;
                        sunk_count_old_bus[0] = HOLD;
                        sunk_count_old_bus[1] = HOLD;

                        if (row < 4'd10 && col < 4'd10)  //Check that it fits if it is horizontal
                            begin
                                valid = 1'b1;
                                data_ready = 1'b0;
                                data_out = 12'b0;
                            end  //Check that if fits if it is vertical
                        else 
                            begin
                                valid = 1'b0;
                                data_ready = 1'b1;
                                data_out = {2'b11, 4'b1111, 4'b1111, player, 1'b0};
                            end
                    end
                CHECK_SHOT_VALID:
                    begin
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_enable[player] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;

                        player_bus = HOLD;
                        direction_bus = HOLD;
                        expected_player_bus = ENABLE;
                        size_bus = RESET;
                        ship_addr_bus = HOLD;
                        row_bus = HOLD;
                        col_bus = HOLD;
                        row_addr_set_bus = HOLD;
                        col_addr_set_bus = HOLD;
                        row_addr_next_bus = HOLD;
                        col_addr_next_bus = HOLD;
                        sunk_count_bus = RESET;
                        sunk_count_old_bus[~player] = HOLD;

                        if (read_data[~player] == 2'b00)      //The cell is empty
                            begin
                                valid = 1'b1;
                                hit = 1'b0;
                                write_enable[~player] = 1'b1;
                                write_data = 2'b01; //Mark the miss, disable writing, and switch players
                                data_ready = 1'b1;
                                data_out = {2'b01, row_addr, col_addr, ~player, 1'b0};

                                sunk_count_old_bus[player] = HOLD;
                            end
                        else if (read_data[~player] == 2'b11)     // The cell is a ship
                            begin
                                valid = 1'b1;
                                hit = 1'b1;
                                write_enable[~player] = 1'b1;
                                write_data = 2'b10;    //Mark the hit and disable writing
                                data_ready = 1'b0;
                                data_out = 12'b0;

                                sunk_count_old_bus[player] = ENABLE;
                            end
                        else                                    //The cell has already be shot at
                            begin
                                valid = 1'b0;
                                hit = 1'b0;
                                write_enable[~player] = 1'b0;
                                write_data = 2'b00;    
                                data_ready = 1'b0;
                                data_out = {2'b11, 4'b1111, 4'b1111, player, 1'b0};

                                sunk_count_old_bus[player] = HOLD;
                            end
                    end
                GET_SHIP_INFO:
                    begin           //Get the info for the ship from Ship Storage
                        hit = 1'b1;
                        valid = 1'b0;
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;
                        data_ready = 1'b0;
                        data_out = 12'b0;

                        player_bus = HOLD;
                        direction_bus = ENABLE;
                        expected_player_bus = HOLD;
                        size_bus = RESET;
                        ship_addr_bus = HOLD;
                        row_bus = HOLD;
                        col_bus = HOLD;
                        row_addr_set_bus = ENABLE;
                        col_addr_set_bus = ENABLE;
                        row_addr_next_bus = HOLD;
                        col_addr_next_bus = HOLD;
                        sunk_count_bus = HOLD;
                        sunk_count_old_bus[0] = HOLD;
                        sunk_count_old_bus[1] = HOLD;
                    end
                CHECK_SUNK:
                    begin
                        hit = hit;
                        valid = valid;
                        expected_player = expected_player;
                        row = row;
                        col = col;
                        player = player;
                        direction = direction; 
                        sunk_count_old[0] = sunk_count_old[0];
                        sunk_count_old[1] = sunk_count_old[1];
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;
                        data_ready = 1'b1;
                        data_out = data_out;
                        if (read_data[~player] == 2'b11) //if it is a ship
                            begin
                                finished_ship = 1'b1;
                                size = 3'b0;
                                sunk_count = sunk_count;
                                row_addr = row_addr;
                                col_addr = col_addr;

                                if (ship_addr == 3'b100) 
                                    begin
                                        all_ships = 1'b1;
                                        ship_addr = 3'b0;;
                                    end
                                else 
                                    begin
                                        all_ships = 1'b0;
                                        ship_addr = ship_addr + 1'b1;
                                    end
                            end
                        else if (size == ship_sizes[ship_addr]-1'b1)
                            begin
                                finished_ship = 1'b1;
                                size = 3'b0;
                                sunk_count = sunk_count + 1'b1;
                                row_addr = row_addr;
                                col_addr = col_addr;
                                if (ship_addr == 3'b100) 
                                    begin
                                        all_ships = 1'b1;
                                        ship_addr = 3'b0;;
                                    end
                                else 
                                    begin
                                        all_ships = 1'b0;
                                        ship_addr = ship_addr + 1'b1;
                                    end
                            end
                        else if (~finished_ship)
                            begin
                                finished_ship = 1'b0;
                                size = size + 1'b1;
                                all_ships = 1'b0;
                                ship_addr = ship_addr;
                                sunk_count = sunk_count;
                                // horizontal
                                if (direction)
                                    begin
                                        row_addr = row_addr;
                                        col_addr = col_addr + 1'b1;
                                    end
                                // vertical
                                else
                                    begin
                                        row_addr = row_addr + 1'b1;
                                        col_addr = col_addr;
                                    end
                            end
                    end
                CHECK_ALL_SUNK:
                    begin
                        hit = 1'b0;
                        valid = valid;
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        expected_player = expected_player;
                        row = row;
                        col = col;
                        player = player;
                        direction = direction;
                        size = 3'd0;
                        sunk_count = sunk_count;
                        sunk_count_old[0] = sunk_count_old[0];
                        sunk_count_old[1] = sunk_count_old[1];
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;
                        row_addr = row_addr;
                        col_addr = col_addr;
                        data_ready = 1'b0;
                        ship_addr = ship_addr;
                        if (sunk_count != sunk_count_old[~player])  data_out = {2'b10, row_addr, col_addr, ~player, 1'b1};
                        else data_out = {2'b10, row_addr, col_addr, ~player, 1'b0};
                    end
                GAME_OVER:
                    begin
                        hit = hit;
                        valid = valid;
                        all_ships = all_ships;
                        finished_ship = finished_ship;
                        expected_player = expected_player;
                        row = row;
                        col = col;
                        player = player;
                        direction = direction; 
                        size = size;
                        sunk_count = sunk_count;
                        sunk_count_old[0] = sunk_count_old[0];
                        sunk_count_old[1] = sunk_count_old[1];
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;
                        row_addr = row_addr;
                        col_addr = col_addr;
                        data_ready = 1'b0;
                        data_out = {2'b01, 4'b1111, 4'b1111, player, 1'b0};
                        ship_addr = ship_addr;
                    end
                default: 
                    begin
                        hit = 1'b0;
                        valid = 1'b0;
                        all_ships = 1'b0;
                        finished_ship = 1'b0;
                        write_data = 2'b00;
                        write_enable[0] = 1'b0;
                        write_enable[1] = 1'b0;
                        write_data_ss = 9'b0;
                        write_enable_ss[0] = 1'b0;
                        write_enable_ss[1] = 1'b0;
                        data_ready = 1'b0;
                        data_out = 12'b0;

                        player_bus = RESET;
                        direction_bus = RESET;
                        expected_player_bus = RESET;
                        size_bus = RESET;
                        ship_addr_bus = RESET;
                        row_bus = RESET;
                        col_bus = RESET;
                        row_addr_set_bus = RESET;
                        col_addr_set_bus = RESET;
                        row_addr_next_bus = RESET;
                        col_addr_next_bus = RESET;
                        sunk_count_bus = RESET;
                        sunk_count_old_bus[0] = RESET;
                        sunk_count_old_bus[1] = RESET;
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
//------------------------------------------------
module gb_mem(input logic ph2, reset, write_enable,
              input logic [3:0] row, col,
              input logic [1:0] write_data,
              output logic [1:0] read_data);
    // write_data:
    // 00 -> nothing, lights off
    // 01 -> miss, blue light
    // 10 -> hit, red light
    // 11 -> ship, green light

    // mem is 10 chunks x 10 chunks, 100 places to store
    // 2 bits per memory location

    logic [19:0] read, write;
    logic [19:0] mem[9:0]; 
    logic [3:0] i;

    assign read = mem[row];

    always_latch
        begin
            if (reset)
                begin
                    mem[0] <= 20'b0;
                    mem[1] <= 20'b0;
                    mem[2] <= 20'b0;
                    mem[3] <= 20'b0;
                    mem[4] <= 20'b0;
                    mem[5] <= 20'b0;
                    mem[6] <= 20'b0;
                    mem[7] <= 20'b0;
                    mem[8] <= 20'b0;
                    mem[9] <= 20'b0;
                end
            else if (write_enable && ph2) mem[row] <= write;
        end

    always_comb
        begin  
            case(col)
                4'd0: read_data = read[1:0];
                4'd1: read_data = read[3:2];
                4'd2: read_data = read[5:4];
                4'd3: read_data = read[7:6];
                4'd4: read_data = read[9:8];
                4'd5: read_data = read[11:10];
                4'd6: read_data = read[13:12];
                4'd7: read_data = read[15:14];
                4'd8: read_data = read[17:16];
                4'd9: read_data = read[19:18];
                default: read_data = read[1:0];
            endcase
        end

    always_comb
        begin
            if(write_enable)
                begin
                    case(col)
                        4'd0: write = {read[19:2], write_data};
                        4'd1: write = {read[19:4], write_data, read[1:0]};
                        4'd2: write = {read[19:6], write_data, read[3:0]};
                        4'd3: write = {read[19:8], write_data, read[5:0]};
                        4'd4: write = {read[19:10], write_data, read[7:0]};
                        4'd5: write = {read[19:12], write_data, read[9:0]};
                        4'd6: write = {read[19:14], write_data, read[11:0]};
                        4'd7: write = {read[19:16], write_data, read[13:0]};
                        4'd8: write = {read[19:18], write_data, read[15:0]};
                        4'd9: write = {write_data, read[17:0]};
                        default: write = {read[19:2], write_data};
                    endcase
                end
            else write = 20'b0;
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
                    mem[0] <= 9'b0;
                    mem[1] <= 9'b0;
                    mem[2] <= 9'b0;
                    mem[3] <= 9'b0;
                    mem[4] <= 9'b0;
                    mem[5] <= 9'b0;
                    mem[6] <= 9'b0;
                    mem[7] <= 9'b0;
                    mem[8] <= 9'b0;
                end
            else if (write_enable && ph2) mem[ship_addr] <= write_data;
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



