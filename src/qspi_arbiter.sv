`default_nettype none

module qspi_arbiter (
    input  wire        clk,
    input  wire        rst_n,
    // Tiny VGA interface
    input  wire  [3:0] column,
    input  wire  [3:0] row,
    input  wire  [7:0] local_x,
    input  wire  [7:0] local_y,
    // QSPI flash & ram interface
    output reg  [23:0] addr,
    output reg         start_read,
    output reg         stop_read,
    output reg         adjust,
    output reg         fifo_clear,
    output wire        fifo_pop,
    input  wire        fifo_empty,
    input  wire        fifo_full,
    input  wire  [4:0] fifo_count,
    // from game logic
    input  wire  [4:0] letter,
    input  wire [23:0] fetch_addr,
    input  wire        fetch
);

reg pending_stop;

reg [23:0] next_addr;
reg next_start_read;
reg next_stop_read;
reg next_adjust;
reg next_fifo_clear;
reg fifo_start_pop;
reg set_pending_stop;
reg clear_pending_stop;

always_comb begin
    next_addr = 24'b00000000_00000000_00000000;
    next_start_read = 0;
    next_stop_read = 0;
    next_adjust = 0;
    next_fifo_clear = 0;
    fifo_start_pop = 0;
    set_pending_stop = 0;
    clear_pending_stop = 0;
    if (!rst_n) begin
        // do nothing
    end else begin
        if (row == 0) begin
            // top screen border, use QSPI pmod to calibrate propagation delay
            next_start_read = column == 0 && local_y == 0 && local_x == 0;
            next_fifo_clear = column == 0 && local_y == 0 && local_x == 0;
            next_adjust = column == 0 && local_y == 0;
            next_stop_read = column == 1 && local_y == 0 && local_x == 0;
        end else if (row >= 1 && row <= 6) begin
            // main screen area, use QSPI pmod to fetch font data
            if (local_y >= 24 && local_y <= 55) begin
                next_addr = {11'b00000000_000, (letter != 0) ? letter : 5'd31, local_y[4:0]-5'd24, 3'b000};
                next_start_read = (column == 0 && local_x == 130-24) || (column >=1 && column <= 4 && local_x == 76-24);
                next_fifo_clear = (column == 0 && local_x == 130-5) || (column >=1 && column <= 4 && local_x == 76-5);
                fifo_start_pop = (column >= 1 && column <= 5 && local_x == 20);
                next_stop_read = (column >= 1 && column <= 5 && local_x == 49);
            end
        end else begin
            // bottom border & off-screen area, use QSPI pmod for word list lookups
            if (pending_stop) begin
                if (fifo_count == 14) begin
                    next_stop_read = 1;
                    clear_pending_stop = 1;
                end
            end else begin
                if (fetch) begin
                    next_addr = fetch_addr;
                    next_start_read = 1;
                    next_fifo_clear = 1;
                    set_pending_stop = 1;
                end
            end
        end
    end
end

always @(posedge clk) begin
    if (next_start_read) addr <= next_addr;
    start_read <= next_start_read;
    stop_read <= next_stop_read;
    adjust <= next_adjust;
    fifo_clear <= next_fifo_clear;
    if (!rst_n) begin
        pending_stop <= 0;
    end else if (clear_pending_stop) begin
        pending_stop <= 0;
    end else if (set_pending_stop) begin
        pending_stop <= 1;
    end
end

reg fifo_try_pop;

always @(posedge clk) begin
    if (!rst_n) begin
        fifo_try_pop <= 0;
    end else begin
        if (fifo_start_pop) fifo_try_pop <= 1;
        if (fifo_empty) fifo_try_pop <= 0;
    end
end

assign fifo_pop = (fifo_try_pop || fifo_full) && !fifo_empty;

endmodule
