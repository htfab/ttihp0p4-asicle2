`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

// Dump the signals to a FST file. You can view it with gtkwave or surfer.
/*initial begin
  $dumpfile("tb.fst");
  $dumpvars(0, tb);
  #1;
end*/

// Wire up the inputs and outputs:
reg clk;
reg rst_n;
reg ena;
reg [7:0] ui_in;
reg [7:0] uio_in;
wire [7:0] uo_out;
wire [7:0] uio_out;
wire [7:0] uio_oe;

tt_um_htfab_asicle2 dut (
    .ui_in  (ui_in),    // Dedicated inputs
    .uo_out (uo_out),   // Dedicated outputs
    .uio_in (uio_in),   // IOs: Input path
    .uio_out(uio_out),  // IOs: Output path
    .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
    .ena    (ena),      // enable - goes high when design is selected
    .clk    (clk),      // clock
    .rst_n  (rst_n)     // not reset
);

wire cs0 = uio_out[0];  // allow triggers on SPI chip select
wire sck = uio_out[3];  // allow triggers on SPI clock
reg [3:0] qspi_in;
assign uio_in = {2'b00, qspi_in[3:2], 1'b0, qspi_in[1:0], 1'b0};
wire [3:0] qspi_out = {uio_out[5:4], uio_out[2:1]};
wire [3:0] qspi_oe = {uio_oe[5:4], uio_oe[2:1]};

initial begin
    clk = 0;
    forever begin
        #20 clk = ~clk;
    end
end

endmodule
