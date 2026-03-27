`default_nettype none

module qspi_sequencer (
    input wire clk,
    input wire rst_n,
    input wire [23:0] addr,
    input wire start_read,
    input wire stop_read,
    output reg reading,
    output reg seq_ready,
    output reg [7:0] uio_out,
    output reg [7:0] uio_oe
);

wire [3:0] addr5 = addr[23:20];
wire [3:0] addr4 = addr[19:16];
wire [3:0] addr3 = addr[15:12];
wire [3:0] addr2 = addr[11: 8];
wire [3:0] addr1 = addr[ 7: 4];
wire [3:0] addr0 = addr[ 3: 0];

wire [7:0] seq_counter;
reg [11:0] microcode;

always_comb begin          //  qspi   qspi  clk  cs  ready
    case (seq_counter)     //   out    oe   mode
        // idle
        8'h00: microcode = 12'b0000___0000___00___1___1;
        // init
        8'h10: microcode = 12'b0000___0000___00___1___0;
        8'h11: microcode = 12'b0000___0000___00___0___0;  // QPI FFh (exit QPI mode)
        8'h12: microcode = 12'b1111___1111___01___0___0;
        8'h13: microcode = 12'b1111___1111___01___0___0;
        8'h14: microcode = 12'b0000___0000___00___0___0;
        8'h15: microcode = 12'b0000___0000___00___1___0;
        8'h16: microcode = 12'b0000___0000___00___0___0;  // SPI 38h (enter QPI mode)
        8'h17: microcode = 12'b0000___0001___01___0___0;
        8'h18: microcode = 12'b0000___0001___01___0___0;
        8'h19: microcode = 12'b0001___0001___01___0___0;
        8'h1a: microcode = 12'b0001___0001___01___0___0;
        8'h1b: microcode = 12'b0001___0001___01___0___0;
        8'h1c: microcode = 12'b0000___0001___01___0___0;
        8'h1d: microcode = 12'b0000___0001___01___0___0;
        8'h1e: microcode = 12'b0000___0001___01___0___0;
        8'h1f: microcode = 12'b0000___0000___00___0___0;
        8'h20: microcode = 12'b0000___0000___00___1___1;
        // start read
        8'h30: microcode = 12'b0000___0000___00___1___0;
        8'h31: microcode = 12'b0000___0000___00___0___0;  // QPI EBh (fast read)
        8'h32: microcode = 12'b1110___1111___01___0___0;
        8'h33: microcode = 12'b1011___1111___01___0___0;
        8'h34: microcode = {addr5, 8'b1111___01___0___0};
        8'h35: microcode = {addr4, 8'b1111___01___0___0};
        8'h36: microcode = {addr3, 8'b1111___01___0___0};
        8'h37: microcode = {addr2, 8'b1111___01___0___0};
        8'h38: microcode = {addr1, 8'b1111___01___0___0};
        8'h39: microcode = {addr0, 8'b1111___01___0___0};
        8'h3a: microcode = 12'b1111___1111___01___0___0;
        8'h3b: microcode = 12'b0000___0000___01___0___0;
        8'h3c: microcode = 12'b0000___0000___10___0___1;
        // end of table
      default: microcode = 12'b0000___0000___00___1___1;
    endcase
end

wire [3:0] qspi_out  = microcode[11:8];
wire [3:0] qspi_oe   = microcode[ 7:4];
wire [1:0] clk_mode  = microcode[ 3:2];
wire       cs_flash  = microcode[   1];
wire       mc_ready  = microcode[   0];

reg [7:0] last_seq;
reg [7:0] new_seq;
reg seq_advance;
reg seq_jump;
assign seq_counter = seq_jump ? new_seq : (seq_advance ? (last_seq + 1) : last_seq);
reg [1:0] spi_clk_counter;
reg stop_read_deferred;

always @(posedge clk) begin
    if (!rst_n) begin
        last_seq <= 8'h00;
        new_seq <= 8'h10;  // init
        seq_advance <= 0;
        seq_jump <= 1;
        spi_clk_counter <= 2'b00;
        reading <= 0;
        stop_read_deferred <= 0;
    end else begin
        last_seq <= seq_counter;
        new_seq <= 8'h00;
        seq_advance <= 0;
        seq_jump <= 0;
        spi_clk_counter <= 2'b00;
        if (stop_read) stop_read_deferred <= 1;
        if (spi_clk_counter != clk_mode) begin
            spi_clk_counter <= spi_clk_counter + 1;
        end else if (!mc_ready) begin
            seq_advance <= 1;
        end else if (stop_read || stop_read_deferred) begin
            stop_read_deferred <= 0;
            seq_jump <= 1;
            new_seq <= 8'h00;  // idle
            reading <= 0;
        end else if (start_read) begin
            seq_jump <= 1;
            new_seq <= 8'h30;  // start read
            reading <= 1;
        end
    end
end

wire spi_clk = spi_clk_counter != 2'b00;
wire next_seq_ready = mc_ready && !stop_read_deferred;
wire [7:0] next_uio_out = {2'b11, qspi_out[3:2], spi_clk, qspi_out[1:0], cs_flash};
wire [7:0] next_uio_oe  = {2'b11,  qspi_oe[3:2],    1'b1,  qspi_oe[1:0],     1'b1};

always @(posedge clk) begin
    if (!rst_n) begin
        seq_ready <= 1'b0;
        uio_out <= 8'b0;
        uio_oe <= 8'b0;
    end else begin
        seq_ready <= next_seq_ready;
        uio_out <= next_uio_out;
        uio_oe <= next_uio_oe;
    end
end

endmodule

