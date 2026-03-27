`default_nettype none

module input_gamepad (
    input  wire        clk,
    input  wire        rst_n,
    input  wire  [7:0] ui_in,
    output reg  [23:0] buttons
);

wire gp_latch = ui_in[4];
wire gp_clk   = ui_in[5];
wire gp_data  = ui_in[6];
wire _unused = &{ui_in[7], ui_in[3:0], 1'b0};

reg last_gp_latch;
reg last_gp_clk;

always @(posedge clk) begin
    if (!rst_n) begin
        last_gp_latch <= 0;
        last_gp_clk <= 0;
    end else begin
        last_gp_latch <= gp_latch;
        last_gp_clk <= gp_clk;
    end
end

wire posedge_gp_clk = gp_clk & ~last_gp_clk;
wire posedge_gp_latch = gp_latch & ~last_gp_latch;

reg valid;
reg [11:0] counter;
reg [11:0] last_counter;
reg [4:0] ticks;
reg [23:0] pending;

always @(posedge clk) begin
    if (!rst_n) begin
        valid <= 1;
        counter <= 0;
        last_counter <= 0;
        ticks <= 0;
        pending <= 0;
        buttons <= 0;
    end else begin
        if (posedge_gp_latch) begin
            if (valid) begin
                if (ticks == 24) begin
                    if ({1'b0, counter} <= {last_counter, 1'b0}) begin
                        buttons <= pending;
                    end
                end
            end
            valid <= 1;
            counter <= 0;
            last_counter <= 0;
            ticks <= 0;
            pending <= 0;
        end else if (posedge_gp_clk) begin
            if (valid) begin
                if (ticks > 1) begin
                    if ({1'b0, counter} > {last_counter, 1'b0}) valid <= 0;
                    if ({counter, 1'b0} < {1'b0, last_counter}) valid <= 0;
                end
                if (ticks >= 24) valid <= 0;
                ticks <= ticks + 1;
                last_counter <= counter;
                counter <= 0;
                if (gp_latch) valid <= 0;
                pending <= {pending[22:0], gp_data};
            end
        end else begin
            if (valid) begin
                if (ticks > 0) begin
                    {valid, counter} <= {valid, counter} + 1;
                end
            end
        end
    end
end

endmodule
