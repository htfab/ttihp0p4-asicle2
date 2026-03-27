`default_nettype none

module qspi_sampler (
    input wire clk,
    input wire rst_n,
    input wire reading,
    input wire seq_ready,
    input wire adjust,
    input wire [7:0] uio_in,
    output reg [3:0] data,
    output reg data_valid
);

wire [3:0] raw_data = {uio_in[5:4], uio_in[2:1]};
wire _unused = &{uio_in[7:6], uio_in[3], uio_in[0], 1'b0};
reg [3:0] last_data;
reg [3:0] before_last_data;

`define MAJ(a, b, c) (((a) & (b)) | ((a) & (c)) | ((b) & (c)))
wire [3:0] majority_data = `MAJ(raw_data, last_data, before_last_data);

reg [3:0] counter;
reg [1:0] counter_phase;
reg [3:0] delay;
reg [1:0] delay_phase;
reg delay_ready;

wire [1:0] next_phase = (counter_phase == 2) ? 0 : (counter_phase + 1);
wire delay_ready_next = delay_ready || (counter == delay && counter_phase == delay_phase);

always @(posedge clk) begin
    if (!rst_n) begin
        last_data <= 0;
        before_last_data <= 0;
        counter <= 0;
        counter_phase <= 0;
        delay <= 0;
        delay_phase <= 0;
        delay_ready <= 0;
        data <= 0;
        data_valid <= 0;
    end else begin
        data <= 0;
        data_valid <= 0;
        if (!reading || !seq_ready) begin
            last_data <= 0;
            before_last_data <= 0;
            counter <= 0;
            counter_phase <= 0;
            delay_ready <= 0;
        end else begin
            last_data <= raw_data;
            before_last_data <= last_data;
            counter_phase <= next_phase;
            if (next_phase == 0) begin
                counter <= counter + 1;
            end
            if (adjust && (raw_data != last_data)) begin
                delay_phase <= counter_phase;
                delay <= counter - raw_data;
            end
            if (!adjust && delay_ready_next) begin
                delay_ready <= 1;
            end
            if (delay_ready && next_phase == delay_phase) begin
                data <= majority_data;
                data_valid <= 1;
            end
        end
    end
end

endmodule

