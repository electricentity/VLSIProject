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
// TO DO: Finish all submodules and compatibility.
//------------------------------------------------
module battleship(input logic ph1, ph2, reset, read, player, direction,
	              input logic [3:0] row, col,
                  output logic sclk, sdo);

    logic       write_enable[1:0], read_enable[1:0];
    logic [1:0] write_data[1:0], read_data[1:0];
    logic [3:0] row_addr[1:0]; // 10 rows required
    logic [3:0] col_addr[1:0]; // 10 columns required
    logic        write_enable_ss[1:0], read_enable_ss[1:0];
    logic [11:0] write_data_ss[1:0], read_data_ss[1:0];


    // Instantiate the FSM controller for the system
    controller c(ph1, ph2, reset, read, player, direction,
                 row, col, row_addr[0], col_addr[0], row_addr[1], col_addr[1],
                 write_data[1:0], read_data[1:0]);

    // Instantiate the memory block for the system
    gb_mem gameboard1(ph2, reset, write_enable[0], read_enable[0],
                      row_addr[0], col_addr[0], write_data[0], read_data[0]);

    gb_mem gameboard2(ph2, reset, write_enable[1], read_enable[1],
                      row_addr[1], col_addr[1], write_data[1], read_data[1]);

    ss_mem shipstorage1(ph2, reset, write_enable, read_enable,
                        ship_addr, write_data, read_data);

    ss_mem shipstorage2(ph2, reset, write_enable, read_enable,
                        ship_addr, write_data, read_data);

    // Instantiate the SPI module
    spi s(sck, sdi, done, data, sdo);

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
                  input logic [1:0]
                  output logic [3:0] row_addr[1:0],
                  output logic [3:0] col_addr[1:0],
                  input logic [3:0] write_data[1:0],
                  input logic [3:0] read_data[1:0]);
    
    logic [4:0] state, nextstate;
    logic pos_valid, shot_valid, expected_player, finished_ship;
    logic [2:0] ship_addr[1:0], size;
    logic [2:0] ship_sizes[4:0];
    logic [3:0] input_row, input_col;
    logic input_player, input_direction;


    // STATES
    parameter INITIAL_START     = ;
    parameter LOAD_SHIP_DATA    = ;
    parameter CHECK_ON_BOARD    = ;
    parameter CHECK_ON_BOARD2   = ;
    parameter CHECK_CELLS       = ;
    parameter SET_SHIP_POS      = ;
    parameter GAME_START        = ;
    parameter LOAD_SHOT_DATA    = ;
    parameter CHECK_SHOT_VALID  = ;
    parameter CHECK_HIT_MISS    = ;
    parameter MARK_SHOT         = ;
    parameter CHECK_SUNK        = ;
    parameter CHECK_ALL_SUNK    = ;
    parameter GAME_OVER         = ;

    // nextstate logic
    always_comb
        case(state)
            // Reset all values
            INITIAL_START:
                begin
                    nextstate <= LOAD_SHIP_DATA;
                end
            // Handle loading player inputs
            LOAD_SHIP_DATA:
                begin
                    if (read) nextstate <= CHECK_POS_VALID;
                    else      nextstate <= LOAD_SHIP_DATA;
                end
            // Handle loading ship based on prev data
            CHECK_ON_BOARD:
                begin
                    nextstate <= CHECK_ON_BOARD2;
                end
            CHECK_ON_BOARD2:
                begin
                    if (pos_valid) nextstate <= CHECK_CELLS;
                    else           nextstate <= LOAD_SHIP_DATA;
                end
            // State will handle setting ship data
            CHECK_CELLS:
                begin
                    if (finished_ship)
                    begin
                        if (pos_valid) nextstate <= SET_SHIP_POS;
                        else           nextstate <= LOAD_SHIP_DATA;
                    end
                    else           nextstate <= CHECK_CELLS;
                end
            SET_SHIP_POS:
                begin
                    if (~finished_ship)
                        begin
                            if (ships_addr[1] == 3'b100) nextstate <= GAME_START;
                            else                    nextstate <= LOAD_SHIP_DATA;
                        end
                    else                            nextstate <= SET_SHIP_POS;
                end
            // Load other stuff; This is a transition state
            GAME_START:
                begin
                    nextstate <= LOAD_SHOT_DATA;
                end
            // State will handle player inputs
            LOAD_SHOT_DATA:
                begin
                    if (read) nextstate <= CHECK_SHOT_VALID;
                    else      nextstate <= LOAD_SHOT_DATA;
                end
            // Check if the shot is valid; IE shot in bounds, not shot already
            CHECK_SHOT_VALID:
                begin
                    if (shot_valid) nextstate <= MARK_SHOT;
                    else            nextstate <= LOAD_SHIP_DATA;
                end
            // Check if shot hits or misses a ship
            CHECK_HIT_MISS:
                begin
                    nextstate <= MARK_SHOT;
                end
            // Save shot, if hit go to LOAD_SHOT_DATA, else go to CHECK_SUNK
            MARK_SHOT:
                begin
                    if (new_shot) nextstate <= LOAD_SHOT_DATA;
                    else          nextstate <= CHECK_SUNK;
                end
            // Check if a ship has sunk
            CHECK_SUNK:
                begin
                    nextstate <= LOAD_SHIP_DATA;
                end
            // Check if all ships sunks
            CHECK_ALL_SUNK:
                begin
                    if (ships_addr[0] == 3'b000) nextstate <= GAME_OVER
                    else if (ships_addr[1] == 3'b000) nextstate <= GAME_OVER
                    nextstate <= LOAD_SHIP_DATA;
                end
            // End the game, it is over!
            GAME_OVER:
                begin
                    nextstate <= GAME_OVER;
                end
            default: nextstate <= INITIAL_START;
        endcase
    end

    // control signal logic
    always_comb
        case(state)
            INITIAL_START:
                begin
                    ship_sizes[0] <= 3'd5;
                    ship_sizes[1] <= 3'd4;
                    ship_sizes[2] <= 3'd3;
                    ship_sizes[3] <= 3'd3;
                    ship_sizes[4] <= 3'd2;
                end
            LOAD_SHIP_DATA:
                begin
                    input_direction <= direction;
                    input_player <= player;
                    input_row <= row;
                    input_col <= col;
                    size <= 3'b0;
                    pos_valid <= 1'b0;
                    finished_ship <= 1'b0;
                end
            CHECK_ON_BOARD:
                begin
                    size <= 3'd0;
                    if (input_direction && input_row < 4'd10 && input_col < (10-ship_sizes[ships_addr[input_player]])) 
                        begin
                            pos_valid <= 1'b1;
                            read_enable[input_player] <= 1'b1;
                            row_addr[input_player] <= input_row;
                            col_addr[input_player] <= input_col;
                        end
                    else if (~input_direction && input_col < 4'd10 && input_row < (10-ship_sizes[ships_addr[input_player]])) 
                        begin
                            pos_valid <= 1'b1;
                            read_enable[input_player] <= 1'b1;
                            row_addr[input_player] <= input_row;
                            col_addr[input_player] <= input_col;
                        end
                    else pos_valid <= 1'b0;
                end
            CHECK_CELLS:
                begin
                    if (read_data[player] != 2'b00)
                        begin
                            pos_valid <= 1'b0;
                            finished_ship <= 1'b1;
                            size <= 3'b0;
                        end
                    else if (size == ship_sizes[ships_addr[player]])
                        begin
                            finished_ship <= 1'b1;
                            size <= 3'b0;
                            write_enable <= 1'b1;
                            write_enable_ss <= 1'b1;
                            row_addr[player] <= input_row;
                            col_addr[player] <= input_col;
                        end
                    else
                        begin
                            size <= size + 1'b1;
                            if (input_direction) // horizontal
                                begin
                                    row_addr[player] <= row_addr[player] + 1'b1;
                                end
                            else // vertical
                                begin
                                    col_addr[player] <= col_addr[player] + 1'b1;
                                end
                        end
                end
            SET_SHIP_POS:
                begin
                    write_data_ss[player] <= {row, col, direction, ship_size[ships_addr[player]};
                    write_enable_ss <= 1'b0;
                    write_data[player] <= 2'b11;
                    if (size == ship_sizes[ships_addr[player]] - 1'b1)
                        begin
                            finished_ship <= 1'b0;
                            size <= 3'b0;
                            write_enable <= 1'b0;
                            write_enable_ss <= 1'b0;
                        end
                    else
                        begin
                            size <= size + 1'b1;
                            if (input_direction) // horizontal
                                begin
                                    row_addr[player] <= row_addr[player] + 1'b1;
                                end
                            else // vertical
                                begin
                                    col_addr[player] <= col_addr[player] + 1'b1;
                                end
                        end     
                end
            GAME_START:
                begin
                    row_addr[player] <= 4'b0000;
                    col_addr[player] <= 4'b0000;
                    row_addr[~player] <= 4'b0000;
                    col_addr[~player] <= 4'b0000;
                end
            LOAD_SHOT_DATA:
                    row_addr[player] <= 4'b0000;
                    col_addr[player] <= 4'b0000;
                    row_addr[~player] <= 4'b0000;
                    col_addr[~player] <= 4'b0000;
                end
            CHECK_SHOT_VALID:
                begin
                    row_addr[player] <= 4'b0000;
                    col_addr[player] <= 4'b0000;
                    row_addr[~player] <= 4'b0000;
                    col_addr[~player] <= 4'b0000;
                end
            CHECK_HIT_MISS:
                begin
                    row_addr[player] <= 4'b0000;
                    col_addr[player] <= 4'b0000;
                    row_addr[~player] <= 4'b0000;
                    col_addr[~player] <= 4'b0000;
                end
            MARK_SHOT:
                begin
                    row_addr[player] <= 4'b0000;
                    col_addr[player] <= 4'b0000;
                    row_addr[~player] <= 4'b0000;
                    col_addr[~player] <= 4'b0000;
                end
            CHECK_SUNK:
                begin
                    row_addr[player] <= 4'b0000;
                    col_addr[player] <= 4'b0000;
                    row_addr[~player] <= 4'b0000;
                    col_addr[~player] <= 4'b0000;
                end
            CHECK_ALL_SUNK:
                begin
                    row_addr[player] <= 4'b0000;
                    col_addr[player] <= 4'b0000;
                    row_addr[~player] <= 4'b0000;
                    col_addr[~player] <= 4'b0000;
                end
            GAME_OVER:
                begin
                    row_addr[player] <= 4'b0000;
                    col_addr[player] <= 4'b0000;
                    row_addr[~player] <= 4'b0000;
                    col_addr[~player] <= 4'b0000;
                end
            default:
                begin
                    row_addr[player] <= 4'b0000;
                    col_addr[player] <= 4'b0000;
                    row_addr[~player] <= 4'b0000;
                    col_addr[~player] <= 4'b0000;
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
module gb_mem(input logic clk, reset, write_enable, read_enable,
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
        if (read_enable) read_data <= mem[row][col];
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
module ss_mem(input logic clk, reset, write_enable, read_enable,
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
        if (read_enable) read_data <= mem[ship_addr];
    end

endmodule


//------------------------------------------------
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
// Module: SPI
// Summary: The module for spi, modified from the E155 version
// TO DO: Change to match our controller/fsm.
//------------------------------------------------
module spi(input  logic sck, sdi, done,
           input  logic [31:0] data,
           output logic sdo);

    logic        sdodelayed, wasdone;
    logic [31:0] data_captured;
               
    // wait until done
    // then apply 32 sclks to shift out data, starting with data[0]

    always_ff @(posedge sck)
        if (!wasdone)  data_captured <= data;
        else           data_captured <= {data_captured[30:0], 1'b0}; 
    end    
    // sdo should change on the negative edge of sck
    always_ff @(negedge sck) begin
        wasdone <= done;
        sdodelayed <= data_captured[30];
    end
    
    // when done is first asserted, shift out msb before clock edge
    assign sdo = (done & !wasdone) ? data[31] : sdodelayed;
endmodule


