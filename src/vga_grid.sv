`default_nettype none

module vga_grid (
    input wire clk,
    input wire rst_n,
    output reg [3:0] column,
    output reg [3:0] row,
    output reg [7:0] local_x,
    output reg [7:0] local_y,
    output reg hsync,
    output reg vsync,
    output reg display_on
);

`define LAST_COLUMN 4'h9
reg [7:0] rollover_x;

always_comb begin
    case (column)
        4'h0: rollover_x = 129;  // left visible border
        4'h1: rollover_x =  75;  // first letter
        4'h2: rollover_x =  75;  // second letter
        4'h3: rollover_x =  75;  // third letter
        4'h4: rollover_x =  75;  // fourth letter
        4'h5: rollover_x =  75;  // fifth letter
        4'h6: rollover_x = 129;  // right visible border
        4'h7: rollover_x =  15;  // right hidden border (front porch)
        4'h8: rollover_x =  95;  // sync pulse
        4'h9: rollover_x =  47;  // left hidden border (back porch)
        default: rollover_x = 0;
    endcase
end

`define LAST_ROW 4'ha
reg [7:0] rollover_y;

always_comb begin
    case (row)
        4'h0: rollover_y =  11;  // top visible border
        4'h1: rollover_y =  75;  // first word
        4'h2: rollover_y =  75;  // second word
        4'h3: rollover_y =  75;  // third word
        4'h4: rollover_y =  75;  // fourth word
        4'h5: rollover_y =  75;  // fifth word
        4'h6: rollover_y =  75;  // sixth word
        4'h7: rollover_y =  11;  // bottom visible border
        4'h8: rollover_y =   9;  // bottom hidden border (front porch)
        4'h9: rollover_y =   1;  // sync pulse
        4'ha: rollover_y =  32;  // top hidden border (back porch)
        default: rollover_y = 0;
    endcase
end

always @(posedge clk) begin
    if (!rst_n) begin
        column <= 0;
        row <= 0;
        local_x <= 0;
        local_y <= 0;
    end else begin
        if (local_x == rollover_x) begin
            local_x <= 0;
            if (column == `LAST_COLUMN) begin
                column <= 0;
                if (local_y == rollover_y) begin
                    local_y <= 0;
                    if (row == `LAST_ROW) begin
                        row <= 0;
                    end else begin
                        row <= row + 1;
                    end
                end else begin
                    local_y <= local_y + 1;
                end
            end else begin
                column <= column + 1;
            end
        end else begin
            local_x <= local_x + 1;
        end
    end
end

always @(posedge clk) begin
    hsync <= (column == `LAST_COLUMN - 1);
    vsync <= (row == `LAST_ROW - 1);
    display_on <= (column < `LAST_COLUMN - 2) && (row < `LAST_ROW - 2);
end

endmodule
