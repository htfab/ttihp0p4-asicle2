`default_nettype none

module game_top (
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
    output wire ack_up, ack_down, ack_left, ack_right, ack_guess,
                ack_soft_new, ack_hard_new, ack_peek, ack_roll, ack_any,
    // interface to qspi module to fetch word list data
    output wire [23:0] fetch_addr,
    output wire fetch,
    input wire [31:0] fetch_result,
    // letter & color for rendering grid cells
    output wire [4:0] letter,
    output wire [2:0] palette_index
);

wire [6:0] word_mask;
wire [4:0] letter_mask;
reg [4:0] new_letter;
reg [2:0] word_index;
reg [2:0] letter_index;
wire [24:0] cross_match_matrix;
wire [24:0] self_match_matrix;

game_board brd (
    .clk,
    .word_index, .letter_index, .letter,
    .word_mask, .letter_mask, .new_letter,
    .cross_match_matrix, .self_match_matrix
);

reg [24:0] cmm_reg;
reg [24:0] smm_reg;

// pipelining to improve crtitical timing path
always @(posedge clk) begin
    cmm_reg <= cross_match_matrix;
    smm_reg <= self_match_matrix;
end

wire [4:0] full_match;
wire [4:0] partial_match;

game_feedback fb (
    .cross_match_matrix(cmm_reg), .self_match_matrix(smm_reg),
    .full_match, .partial_match
);

game_logic gl (
    .clk, .rst_n,
    .column, .row, .local_x, .local_y,
    .btn_up, .btn_down, .btn_left, .btn_right, .btn_guess, .btn_soft_new, .btn_hard_new, .btn_peek, .btn_roll, .btn_any,
    .ack_up, .ack_down, .ack_left, .ack_right, .ack_guess, .ack_soft_new, .ack_hard_new, .ack_peek, .ack_roll, .ack_any,
    .fetch_addr, .fetch, .fetch_result,
    .word_index, .letter_index, .letter,
    .word_mask, .letter_mask, .new_letter,
    .full_match, .partial_match,
    .palette_index
);

endmodule

