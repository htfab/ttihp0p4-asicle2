`default_nettype none

module tt_um_htfab_asicle2 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

wire btn_up, btn_down, btn_left, btn_right, btn_guess, btn_soft_new, btn_hard_new, btn_peek, btn_roll, btn_any;
wire ack_up, ack_down, ack_left, ack_right, ack_guess, ack_soft_new, ack_hard_new, ack_peek, ack_roll, ack_any;

input_top inp (
    .clk, .rst_n,
    .ui_in,
    .btn_up, .btn_down, .btn_left, .btn_right, .btn_guess, .btn_soft_new, .btn_hard_new, .btn_peek, .btn_roll, .btn_any,
    .ack_up, .ack_down, .ack_left, .ack_right, .ack_guess, .ack_soft_new, .ack_hard_new, .ack_peek, .ack_roll, .ack_any
);

wire [3:0] column;
wire [3:0] row;
wire [7:0] local_x;
wire [7:0] local_y;
wire [1:0] pixel_data;
wire pixel_data_valid;
wire [2:0] palette_index;

vga_top vga (
    .clk, .rst_n,
    .column, .row, .local_x, .local_y,
    .pixel_data, .pixel_data_valid,
    .palette_index,
    .uo_out
);

wire [4:0] letter;
wire [23:0] fetch_addr;
wire fetch;
wire [31:0] fetch_result;

qspi_top qspi (
    .clk, .rst_n,
    .column, .row, .local_x, .local_y,
    .letter, .pixel_data, .pixel_data_valid,
    .fetch_addr, .fetch, .fetch_result,
    .uio_in, .uio_out, .uio_oe
);

game_top game (
    .clk, .rst_n,
    .column, .row, .local_x, .local_y,
    .btn_up, .btn_down, .btn_left, .btn_right, .btn_guess, .btn_soft_new, .btn_hard_new, .btn_peek, .btn_roll, .btn_any,
    .ack_up, .ack_down, .ack_left, .ack_right, .ack_guess, .ack_soft_new, .ack_hard_new, .ack_peek, .ack_roll, .ack_any,
    .fetch_addr, .fetch, .fetch_result,
    .letter,
    .palette_index
);

wire _unused = &{ena, 1'b0};

endmodule
