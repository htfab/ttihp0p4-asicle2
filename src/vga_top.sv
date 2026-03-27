`default_nettype none

module vga_top (
    input wire clk,
    input wire rst_n,
    // screen coordinates, used in several places through the design
    output wire [3:0] column,
    output wire [3:0] row,
    output wire [7:0] local_x,
    output wire [7:0] local_y,
    // streaming font data from QSPI flash
    input wire [1:0] pixel_data,
    input wire pixel_data_valid,
    // style of current square from game logic
    input wire [2:0] palette_index,
    // connected to the Tiny VGA pmod
    output wire [7:0] uo_out
);

wire hsync;
wire vsync;
wire display_on;

vga_grid grid (
    .clk, .rst_n,
    .column, .row, .local_x, .local_y,
    .hsync, .vsync, .display_on
);

wire [1:0] red;
wire [1:0] green;
wire [1:0] blue;

vga_render render (
    .clk, .rst_n,
    .column, .row, .local_x, .local_y,
    .pixel_data, .pixel_data_valid,
    .palette_index,
    .red, .green, .blue
);

assign uo_out = {
    hsync,
    blue[0] & display_on,
    green[0] & display_on,
    red[0] & display_on,
    vsync,
    blue[1] & display_on,
    green[1] & display_on,
    red[1] & display_on
};

endmodule
