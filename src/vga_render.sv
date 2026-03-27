`default_nettype none

module vga_render (
    input  wire        clk,
    input  wire        rst_n,
    // pixel coordinates from vga timing generator
    input  wire  [3:0] column,
    input  wire  [3:0] row,
    input  wire  [7:0] local_x,
    input  wire  [7:0] local_y,
    // colors to send to Tiny VGA pmod
    output reg   [1:0] red,
    output reg   [1:0] green,
    output reg   [1:0] blue,
    // streaming font data from QSPI flash
    input  wire  [1:0] pixel_data,
    input  wire        pixel_data_valid,
    // style of current square from game logic
    input  wire  [2:0] palette_index
);

reg [29:0] palette;
always_comb begin
    case (palette_index)   //   00         01         10         11       border
            0: palette = 30'b00_00_00___01_01_01___10_10_10___11_11_11___01_01_01;  // white on black, dark grey outline
            1: palette = 30'b00_00_00___01_01_01___10_10_10___11_11_11___10_10_10;  // white on black, light grey outline (selection)
            2: palette = 30'b00_00_00___01_00_00___10_01_01___11_01_01___01_01_01;  // red on black, dark grey outline (invalid guess)
            3: palette = 30'b00_00_00___01_00_00___10_01_01___11_01_01___10_10_10;  // red on black, light grey outline (selection + invalid)
            4: palette = 30'b01_01_01___10_10_10___10_10_10___11_11_11___01_01_01;  // dark grey background (no match)
            5: palette = 30'b10_10_01___10_10_10___11_11_10___11_11_11___10_10_01;  // yellow background (match in wrong position)
            6: palette = 30'b01_10_01___10_10_10___10_11_10___11_11_11___01_10_01;  // green background (match in correct position)
      default: palette = 30'b00_00_00___01_01_01___10_10_10___11_11_11___01_01_01;
    endcase
end

wire [5:0] gradient_color [3:0];
assign gradient_color[0] = palette[29:24];
assign gradient_color[1] = palette[23:18];
assign gradient_color[2] = palette[17:12];
assign gradient_color[3] = palette[11: 6];
wire [5:0] border_color  = palette[ 5: 0];

reg last_pixel_data_valid;

always @(posedge clk) begin
    if (!rst_n) begin
        {red, green, blue} <= 6'b00_00_11;
        last_pixel_data_valid <= 0;
    end else begin
        last_pixel_data_valid <= pixel_data_valid;
        if (row >= 1 && row <= 6 && column >= 1 && column <= 5) begin
            if (local_y >= 24 && local_y <= 55 && local_x >= 22 && local_x <= 53) begin
                if (last_pixel_data_valid) begin
                    {red, green, blue} <= gradient_color[pixel_data];
                end else begin
                    {red, green, blue} <= 6'b00_00_11;
                end
            end else if (local_y >= 6 && local_y <= 69 && local_x >= 6 && local_x <= 69) begin
                {red, green, blue} <= gradient_color[0];
            end else if (local_y >= 3 && local_y <= 72 && local_x >= 3 && local_x <= 72) begin
                {red, green, blue} <= border_color;
            end else begin
                {red, green, blue} <= 6'b00_00_00;
            end
        end else begin
            {red, green, blue} <= 6'b00_00_00;
        end
    end
end

endmodule
