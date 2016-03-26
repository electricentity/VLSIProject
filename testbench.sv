//------------------------------------------------
// battleship.sv
// Authors: Jacob Nguyen and Michael Reeve
// Date: March 19, 2016
// VLSI Final Project: Battleship
//------------------------------------------------

module testbench();

    // 14 bits of input
    logic ph1, ph2, reset, read, player, direction;
    logic [3:0] row, col;
    // 13 bits of output
    logic data_ready;
    logic [11:0] data_out, data_out_expected;

    // Instantiate Device Under Test (DUT)
    battleship dut(ph1, ph2, reset, read, player, direction, row, col, data_out, data_ready);
    
    // Logic for reading in vectors
    logic [23:0] vectors[200:0], currentvec;
    logic [15:0] vectornum, errors;

    // read test vector file and initialize test
    initial begin
        $readmemb("battleship.tv", vectors);
        vectornum = 0; errors = 0;
    end

    // generate a clock to sequence tests
    always begin
        ph1 = 0; ph2 = 0; #5;
        ph1 = 1; ph2 = 0; #5;
        ph1 = 0; ph2 = 0; #5;
        ph1 = 0; ph2 = 1; #5;
    end
    // apply test
    always @(posedge ph1) 
        begin
            // set test vectors when required
            currentvec = vectors[vectornum];
            reset = currentvec[23];
            read = currentvec[22];
            player = currentvec[21];
            direction = currentvec[20];
            row = currentvec[19:16];
            col = currentvec[15:12];
            data_out_expected = currentvec[11:0];

        // End the test
        if (currentvec[0] == 1'bx)
            begin
                $display("Test completed with %d errors", errors);
                $stop;
            end
        end

    // check if test was sucessful and apply next one
    always @(posedge ph2)
        begin
        $display("Vectornum =%d ", vectornum);
            if (data_ready)
                begin
                    // We get an unexpected value
                    $display("Vectornum =%d ", vectornum);
                    if (data_out != data_out_expected)
                        begin
                            errors = errors + 1;
                            $display("Error: Vectornum =%d ", vectornum);
                            $display("    data_out -> (%h, actual) | (%h expected)",
                                          data_out, data_out_expected);
                        end
                    vectornum = vectornum + 1;
                end
        end
endmodule