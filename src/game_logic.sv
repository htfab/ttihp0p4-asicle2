`default_nettype none

module game_logic (
    input wire clk,
    input wire rst_n,
    // part of screen being rendered
    input wire [3:0] column,
    input wire [3:0] row,
    input wire [7:0] local_x,
    input wire [7:0] local_y,
    // button press events
    input wire btn_up, btn_down, btn_left, btn_right, btn_guess,
               btn_soft_new, btn_hard_new, btn_peek, btn_roll, btn_any,
    // acknowledgement of button presses
    output reg ack_up, ack_down, ack_left, ack_right, ack_guess,
               ack_soft_new, ack_hard_new, ack_peek, ack_roll, ack_any,
    // interface to qspi module to fetch word list data
    output reg [23:0] fetch_addr,
    output reg fetch,
    input wire [31:0] fetch_result,
    // read a letter from the game board
    output reg [2:0] word_index,
    output reg [2:0] letter_index,
    input wire [4:0] letter,
    // update the game board
    output wire [6:0] word_mask,
    output wire [4:0] letter_mask,
    output reg [4:0] new_letter,
    // letters to highlight in green & yellow
    input wire [4:0] full_match,
    input wire [4:0] partial_match,
    // background and border color for current cell
    output reg [2:0] palette_index
);

wire correct_guess = &full_match;

reg [2:0] current_row;
reg [2:0] current_column;
reg update_letter;
reg valid_word;
reg invalid_feedback;
reg game_over;
reg new_game;
reg peek_mode;
reg roll_mode;
reg letter_available;

wire [6:0] word_index_onehot;
wire [4:0] letter_index_onehot;
generate genvar i;
for (i=0; i<7; i=i+1) assign word_index_onehot[i] = (word_index == i);
for (i=0; i<5; i=i+1) assign letter_index_onehot[i] = (letter_index == i);
endgenerate
wire reset_board = !rst_n || new_game;
assign word_mask = word_index_onehot | {7{reset_board}};
assign letter_mask = ( letter_index_onehot | {5{reset_board}} ) & {5{update_letter}};

always @(posedge clk) begin
    if (!rst_n) begin
        update_letter <= 1;
        new_letter <= 0;
        word_index <= 0;
        letter_index <= 0;
        current_row <= 1;
        current_column <= 1;
        invalid_feedback <= 0;
        game_over <= 0;
        palette_index <= 0;
        new_game <= 0;
        peek_mode <= 0;
        roll_mode <= 1;
        letter_available <= 0;
        {ack_up, ack_down, ack_left, ack_right, ack_guess, ack_soft_new, ack_hard_new, ack_peek, ack_roll, ack_any} <= 0;
    end else begin
        update_letter <= 0;
        new_letter <= 0;
        new_game <= 0;
        letter_available <= 0;
        {ack_up, ack_down, ack_left, ack_right, ack_guess, ack_soft_new, ack_hard_new, ack_peek, ack_roll, ack_any} <= 0;
        if (row <= 6) begin
            // keep the right letter selected for font rendering
            word_index <= (peek_mode && row == 6) ? 3'd0 : 3'(row);
            letter_index <= 3'(column);
            if (column >= 1 && column <= 5) begin
                if (row < 4'(current_row)) begin
                    palette_index <= full_match[column-1] ? 6 : (partial_match[column-1] ? 5 : 4);
                end else begin
                    palette_index <= {1'b0, row == 4'(current_row) && invalid_feedback,
                                      row == 4'(current_row) && column == 4'(current_column) && !game_over};
                end
            end
        end else if (row == 7) begin
            // process button presses
            word_index <= current_row;
            letter_index <= current_column-1;
            if (word_index == current_row && letter_index == current_column-1) begin
                letter_available <= 1;
                if (btn_any) begin
                    ack_any <= 1;
                    invalid_feedback <= 0;
                end
                if (btn_soft_new || btn_hard_new) begin
                    ack_soft_new <= btn_soft_new;
                    ack_hard_new <= btn_hard_new;
                    if (btn_hard_new || game_over) begin
                        new_game <= 1;
                        update_letter <= 1;
                        new_letter <= 0;
                        current_row <= 1;
                        current_column <= 1;
                        game_over <= 0;
                        roll_mode <= 1;
                    end
                end else if (btn_guess) begin
                    if (letter_available) begin
                        ack_guess <= 1;
                        if (!game_over) begin
                            if (valid_word) begin
                                current_row <= current_row + 1;
                                current_column <= 1;
                                roll_mode <= 0;
                                if (correct_guess || current_row == 6) begin
                                    game_over <= 1;
                                end
                            end else begin
                                invalid_feedback <= 1;
                            end
                        end
                    end
                end else if (btn_up) begin
                    if (letter_available) begin
                        ack_up <= 1;
                        if (!game_over) begin
                            update_letter <= 1;
                            if (letter > 0 && letter <= 26) begin
                                new_letter <= letter - 1;
                            end else begin
                                new_letter <= 26;
                            end
                        end
                    end
                end else if (btn_down) begin
                    if (letter_available) begin
                        ack_down <= 1;
                        if (!game_over) begin
                            update_letter <= 1;
                            if (letter < 26) begin
                                new_letter <= letter + 1;
                            end else if (letter == 26) begin
                                new_letter <= 0;
                            end else begin
                                new_letter <= 1;
                            end
                        end
                    end
                end else if (btn_left) begin
                    ack_left <= 1;
                    if (!game_over) begin
                        if (current_column > 1) begin
                            current_column <= current_column - 1;
                        end
                    end
                end else if (btn_right) begin
                    ack_right <= 1;
                    if (!game_over) begin
                        if (current_column < 5) begin
                            current_column <= current_column + 1;
                        end
                    end
                end else if (btn_peek) begin
                    ack_peek <= 1;
                    peek_mode <= !peek_mode;
                end else if (btn_roll) begin
                    ack_roll <= 1;
                    roll_mode <= !roll_mode;
                end
            end
        end else begin
            if (row == 8 && local_x == 0) begin
                if (local_y == 1) begin
                    if (roll_mode) begin
                        // keep updating the solution until the first guess (for randomness)
                        word_index <= 0;
                        if (column == 2) begin
                            letter_index <= 0;
                            update_letter <= 1;
                            new_letter <= fetch_result[31:27];
                        end else if (column == 3) begin
                            letter_index <= 1;
                            update_letter <= 1;
                            new_letter <= fetch_result[26:22];
                        end else if (column == 4) begin
                            letter_index <= 2;
                            update_letter <= 1;
                            new_letter <= fetch_result[21:17];
                        end else if (column == 5) begin
                            letter_index <= 3;
                            update_letter <= 1;
                            new_letter <= fetch_result[16:12];
                        end else if (column == 6) begin
                            letter_index <= 4;
                            update_letter <= 1;
                            new_letter <= fetch_result[11: 7];
                        end
                    end
                end else if (local_y >= 2 && local_y <= 6) begin
                    // check whether the current word is in the dictionary
                    if (column == 0) begin
                        word_index <= current_row;
                        letter_index <= 3'(local_y) - 3'd2;
                    end else if (column == 2) begin
                        word_index <= 3'(local_y);
                        letter_index <= 0;
                    end else if (column == 3) begin
                        letter_index <= 1;
                    end else if (column == 4) begin
                        letter_index <= 2;
                    end else if (column == 5) begin
                        letter_index <= 3;
                    end else if (column == 6) begin
                        letter_index <= 4;
                    end
                end
            end
        end
    end
end

reg [12:0] word_pick;
reg [12:0] lookup_state;
reg [23:0] next_fetch_addr;
reg next_fetch;

always_comb begin
    next_fetch_addr = 0;
    next_fetch = 0;
    if (!rst_n) begin
        // do nothing
    end else begin
        if (row == 8 && column == 1 && local_x == 0) begin
            if (local_y == 0) begin
                // fetch number of picks (possible solution words)
                next_fetch_addr = {24'b00000000_00100000_00000000};
                next_fetch = 1;
            end else if (local_y == 1) begin
                // fetch the current pick (based on index in word_pick)
                next_fetch_addr = {9'b00000000_0, 13'b0100000_000000 + word_pick, 2'b00};
                next_fetch = 1;
            end else if (local_y >= 2 && local_y <= 6) begin
                // look up current word in the dictionary trie
                next_fetch_addr = {5'b00000, 13'b000_10000000_00 + lookup_state, letter, 1'b0};
                next_fetch = 1;
            end
        end
    end
end

// pipelining to improve crtitical timing path
always @(posedge clk) begin
    fetch_addr <= next_fetch_addr;
    fetch <= next_fetch;
end

always @(posedge clk) begin
    if (!rst_n) begin
        word_pick <= 1;
    end else begin
        if (row == 8 && local_x == 0) begin
            if (local_y == 0) begin
                // rotate the current pick index (for randomness)
                if (column == 6) begin
                    if (word_pick < fetch_result[12:0]) begin
                        word_pick <= word_pick + 1;
                    end else begin
                        word_pick <= 1;
                    end
                end
            end else if (local_y == 2) begin
                // initialize the trie for dictionary lookup
                if (column == 0) begin
                    lookup_state <= 2;
                end
            end else if (local_y >=3 && local_y <= 7) begin
                // update the trie state based on the next letter
                if (column == 0) begin
                    lookup_state <= fetch_result[28:16];
                end
            end else if (local_y == 8) begin
                // store whether the current word is in the dictionary
                valid_word <= lookup_state != 0;
            end
        end
    end
end

endmodule
