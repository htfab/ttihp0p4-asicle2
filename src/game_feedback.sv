`default_nettype none

module game_feedback (
    input wire [24:0] cross_match_matrix,
    input wire [24:0] self_match_matrix,
    output reg [4:0] full_match,
    output reg [4:0] partial_match
);

reg [2:0] i;
reg [2:0] j;
reg [2:0] cross_count;
reg [2:0] self_count;

always_comb begin
    for (i=0; i<5; i=i+1) begin
        full_match[i] = cross_match_matrix[5*i+i];
    end
    for (i=0; i<5; i=i+1) begin
        cross_count = 0;
        self_count = 0;
        for (j=0; j<5; j=j+1) begin
            if (!full_match[j]) begin
                if (cross_match_matrix[5*i+j]) begin
                    cross_count = cross_count + 1;
                end
                if (self_match_matrix[5*i+j] && j <= i) begin
                    self_count = self_count + 1;
                end
            end
        end
        partial_match[i] = cross_count >= self_count;
    end
end

endmodule

