`default_nettype none

module game_board (
    input  wire        clk,
    // update letters
    input  wire  [6:0] word_mask,
    input  wire  [4:0] letter_mask,
    input  wire  [4:0] new_letter,
    // read current letter
    input  wire  [2:0] word_index,
    input  wire  [2:0] letter_index,
    output reg   [4:0] letter,
    // check matches to calculate colors
    output wire [24:0] cross_match_matrix,
    output wire [24:0] self_match_matrix
);

(* mem2reg *)
reg [4:0] board [6:0][4:0];  // word 0 is the solution

// pipelining to improve crtitical timing path
always @(posedge clk) begin
    letter <= board[word_index][letter_index];
end

generate genvar i, j;
for (j=0; j<7; j=j+1) begin
    for (i=0; i<5; i=i+1) begin
        always @(posedge clk) begin
            if (word_mask[j] && letter_mask[i]) begin
                board[j][i] <= new_letter;
            end
        end
    end
end
for (i=0; i<5; i=i+1) begin
    for (j=0; j<5; j=j+1) begin
        assign cross_match_matrix[5*i+j] = (board[word_index][i] == board[0][j]);
        assign self_match_matrix[5*i+j] = (board[word_index][i] == board[word_index][j]);
    end
end
endgenerate

endmodule
