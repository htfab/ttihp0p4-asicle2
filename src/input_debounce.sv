`default_nettype none
`define INPUTS 32

module input_debounce (
    input wire clk,
    input wire rst_n,
    input wire [`INPUTS-1:0] inputs,
    output reg [`INPUTS-1:0] held_down,
    output reg [`INPUTS-1:0] just_pressed,
    output reg [`INPUTS-1:0] just_released
);

reg [15:0] counter;
reg [`INPUTS-1:0] pending_changes;

wire [`INPUTS-1:0] next_pending_changes = pending_changes & (held_down ^ inputs);

always @(posedge clk) begin
    if (!rst_n) begin
        counter <= 0;
        held_down <= inputs;
        pending_changes <= 0;
        just_pressed <= 0;
        just_released <= 0;
    end else begin
        counter <= counter + 1;
        just_pressed <= 0;
        just_released <= 0;
        if (counter == 0) begin
            just_pressed <= ~held_down & next_pending_changes;
            just_released <= held_down & next_pending_changes;
            held_down <= held_down ^ next_pending_changes;
            pending_changes <= {`INPUTS{1'b1}};
        end else begin
            pending_changes <= next_pending_changes;
        end
    end
end

endmodule
