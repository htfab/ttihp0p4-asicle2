`default_nettype none

module input_top (
    input wire clk,
    input wire rst_n,
    // connected to gamepad pmod or driven directly
    input wire [7:0] ui_in,
    // button presses pending to be processed by game logic
    output wire btn_up, btn_down, btn_left, btn_right, btn_guess,
                btn_soft_new, btn_hard_new, btn_peek, btn_roll, btn_any,
    // acknowledgement from game logic that button presses were processed
    input wire ack_up, ack_down, ack_left, ack_right, ack_guess,
               ack_soft_new, ack_hard_new, ack_peek, ack_roll, ack_any
);

// bring inputs into clock domain
reg [7:0] ui_in_sync1;
reg [7:0] ui_in_sync2;
always @(posedge clk) begin
    ui_in_sync1 <= ui_in;
    ui_in_sync2 <= ui_in_sync1;
end

// decode gamepad inputs
wire [23:0] gp_buttons;
input_gamepad gp (
    .clk, .rst_n,
    .ui_in(ui_in_sync2),
    .buttons(gp_buttons)
);

// debounce both direct inputs and those decoded from the gamepad
// (pulses from the gamepad are ignored as direct inputs as they are too short)
wire [31:0] held_down;
wire [31:0] just_pressed;
wire [31:0] just_released;
input_debounce db (
    .clk, .rst_n,
    .inputs({gp_buttons, ui_in_sync2}),
    .held_down, .just_pressed, .just_released
);

// convert physical button presses to logical actions for the game
input_logic il (
    .clk, .rst_n,
    .held_down, .just_pressed,
    .btn_up, .btn_down, .btn_left, .btn_right, .btn_guess,
        .btn_soft_new, .btn_hard_new, .btn_peek, .btn_roll, .btn_any,
    .ack_up, .ack_down, .ack_left, .ack_right, .ack_guess,
        .ack_soft_new, .ack_hard_new, .ack_peek, .ack_roll, .ack_any
);

wire _unused = &{just_released, 1'b0};

endmodule

