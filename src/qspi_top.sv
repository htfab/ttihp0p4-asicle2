`default_nettype none

module qspi_top (
    input wire clk,
    input wire rst_n,
    // arbitrate qspi access based on part of the screen rendered
    input wire [3:0] column,
    input wire [3:0] row,
    input wire [7:0] local_x,
    input wire [7:0] local_y,
    // fast path directly to the display for font rendering
    input wire [4:0] letter,
    output wire [1:0] pixel_data,
    output wire pixel_data_valid,
    // slow path to the game logic for word list access
    input wire [23:0] fetch_addr,
    input wire fetch,
    output wire [31:0] fetch_result,
    // qspi pmod connected to uio pins
    input wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe
);

// - generate queries for latency calibration in the top border region
// - generate font queries in the grid cells
// - pass through word list queries when off-screen

wire [23:0] addr;
wire start_read;
wire stop_read;
wire adjust;
wire fifo_empty;
wire fifo_full;
wire [4:0] fifo_count;
wire fifo_clear;
wire fifo_pop;

qspi_arbiter arb (
    .clk, .rst_n,
    .column, .row, .local_x, .local_y,     // area of screen being rendered
    .addr, .start_read, .stop_read,        // queries to the qspi pmod via the sequencer
    .adjust,                               // trigger adjustment of propagation delay
    .letter,                               // current letter for generating font queries
    .fetch_addr, .fetch,                   // pass through queries from game logic
    .fifo_empty, .fifo_full, .fifo_count,  // fifo manipulation to make data available at the right time
        .fifo_clear, .fifo_pop
);

// manipulate uio pins to request data from flash chip on qspi pmod

wire reading;
wire seq_ready;

qspi_sequencer seq (
    .clk, .rst_n,
    .addr, .start_read, .stop_read,        // queries to send to qspi pmod
    .reading, .seq_ready,                  // current status of sequencer
    .uio_out, .uio_oe                      // write access to the uio pins
);

// measure round-trip latency from qspi pmod and sample incoming data accordingly

wire [3:0] fifo_push_data;
wire fifo_push;

qspi_sampler samp (
    .clk, .rst_n,
    .reading, .seq_ready,                  // sequencer status
    .adjust,                               // request from arbiter to measure latency
    .uio_in,                               // read access to the uio pins
    .data(fifo_push_data),                 // relay sampled data to the fifo
        .data_valid(fifo_push)
);

// hold incoming data so that it can be accessed with the right timing

wire [1:0] fifo_pop_data;
wire [31:0] fifo_buffer;

qspi_fifo fifo (
    .clk, .rst_n,
    .empty(fifo_empty), .full(fifo_full),  // fifo status for arbiter
        .count(fifo_count),
    .clear(fifo_clear), .pop(fifo_pop),    // triggers from arbiter
    .push(fifo_push),                      // input stream from sampler
        .push_data(fifo_push_data),
    .pop_data(fifo_pop_data),              // output stream to display
    .buffer(fifo_buffer)                   // output value to game logic
);

assign pixel_data = fifo_pop_data;
assign pixel_data_valid = fifo_pop;
assign fetch_result = fifo_buffer;

endmodule

