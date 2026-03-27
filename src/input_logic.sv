`default_nettype none

module input_logic (
    input wire clk,
    input wire rst_n,
    // debounced inputs, both directly and decoded from gamepad pmod
    input wire [31:0] held_down,
    input wire [31:0] just_pressed,
    // button presses pending to be processed by game logic
    output wire btn_up, btn_down, btn_left, btn_right, btn_guess,
                btn_soft_new, btn_hard_new, btn_peek, btn_roll, btn_any,
    // acknowledgement from game logic that button presses were processed
    input wire ack_up, ack_down, ack_left, ack_right, ack_guess,
               ack_soft_new, ack_hard_new, ack_peek, ack_roll, ack_any
);

// map button indices to their functionality
// (for gamepad inputs, we only accept "start" (new), "X" (peek) & "Y" (roll) when
//  pressed together with "select" to prevent triggering them accidentally)
wire [7:0] direct;
wire [11:0] gp1;
wire [11:0] gp2;
wire gp1_b, gp1_y, gp1_select, gp1_start, gp1_up, gp1_down, gp1_left, gp1_right, gp1_a, gp1_x, gp1_l, gp1_r;
wire gp2_b, gp2_y, gp2_select, gp2_start, gp2_up, gp2_down, gp2_left, gp2_right, gp2_a, gp2_x, gp2_l, gp2_r;
assign {gp2, gp1, direct} = just_pressed;
wire gp1_connected = ~&gp1;  // pmod signals all 1's if gamepad is not plugged in
wire gp2_connected = ~&gp2;
assign {gp1_b, gp1_y, gp1_select, gp1_start, gp1_up, gp1_down, gp1_left, gp1_right, gp1_a, gp1_x, gp1_l, gp1_r} = gp1 & {12{gp1_connected}};
assign {gp2_b, gp2_y, gp2_select, gp2_start, gp2_up, gp2_down, gp2_left, gp2_right, gp2_a, gp2_x, gp2_l, gp2_r} = gp2 & {12{gp2_connected}};
wire gp1_force = held_down[17];  // gp1 select
wire gp2_force = held_down[29];  // gp2 select
reg debug_mode;
wire combined_up    = direct[0] || gp1_up    || gp2_up;
wire combined_down  = direct[1] || gp1_down  || gp2_down;
wire combined_left  = direct[2] || gp1_left  || gp2_left;
wire combined_right = direct[3] || gp1_right || gp2_right;
wire combined_guess = direct[4] || gp1_a     || gp2_a;
wire combined_soft_new = gp1_start && !gp1_force || gp2_start && !gp2_force;
wire combined_hard_new = direct[5] || gp1_start && gp1_force || gp2_start && gp2_force;
wire combined_peek  = direct[6] || (gp1_x && gp1_force || gp2_x && gp2_force) && debug_mode;
wire combined_roll  = direct[7] || (gp1_y && gp1_force || gp2_y && gp2_force) && debug_mode;
wire combined_any   = (|direct) || (|gp1) || (|gp2);
wire [9:0] combined_inputs = {combined_any, combined_roll, combined_peek, combined_hard_new, combined_soft_new,
                              combined_guess, combined_right, combined_left, combined_down, combined_up};

// enable debug mode using Konami code
reg [3:0] debug_progress;
reg debug_next;
always_comb begin
    case (debug_progress)
        0: debug_next = gp1_up    || gp2_up;
        1: debug_next = gp1_up    || gp2_up;
        2: debug_next = gp1_down  || gp2_down;
        3: debug_next = gp1_down  || gp2_down;
        4: debug_next = gp1_left  || gp2_left;
        5: debug_next = gp1_right || gp2_right;
        6: debug_next = gp1_left  || gp2_left;
        7: debug_next = gp1_right || gp2_right;
        8: debug_next = gp1_b     || gp2_b;
        9: debug_next = gp1_a     || gp2_a;
        default: debug_next = 1'b0;
    endcase
end
always @(posedge clk) begin
    if (!rst_n) begin
        debug_mode <= 0;
        debug_progress <= 0;
    end else begin
        if (!debug_mode && combined_any) begin
            if (debug_next) begin
                if (debug_progress == 9) begin
                    debug_mode <= 1;
                end else begin
                    debug_progress <= debug_progress + 1;
                end
            end else begin
                debug_progress <= 0;
            end
        end
    end
end

// mark pressed buttons as pending until acknowledged by game logic
reg [9:0] pending;
wire [9:0] acked = {ack_any, ack_roll, ack_peek, ack_hard_new, ack_soft_new, ack_guess, ack_right, ack_left, ack_down, ack_up};
wire [9:0] non_acked = pending & ~acked;
assign {btn_any, btn_roll, btn_peek, btn_hard_new, btn_soft_new, btn_guess, btn_right, btn_left, btn_down, btn_up} = non_acked;

always @(posedge clk) begin
    if (!rst_n) begin
        pending <= 0;
    end else begin
        pending <= non_acked | combined_inputs;
    end
end

wire _unused = &{held_down[31:30], held_down[28:18], held_down[16:0], gp1_select, gp1_l, gp1_r, gp2_select, gp2_l, gp2_r};

endmodule

