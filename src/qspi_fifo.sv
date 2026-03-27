`default_nettype none

`define SIZE 24

module qspi_fifo (
    input wire clk,
    input wire rst_n,
    input wire clear,
    input wire push,
    input wire [3:0] push_data,
    input wire pop,
    output reg [1:0] pop_data,
    output wire empty,
    output wire full,
    output wire [4:0] count,
    output wire [31:0] buffer
);

reg [2*`SIZE-1:0] queue;
reg [$clog2(`SIZE+1)-1:0] index;

assign empty = (index == 0);
assign full = (index >= `SIZE-1);

always @(posedge clk) begin
    if (!rst_n) begin
        index <= 0;
    end else if (clear) begin
        index <= 0;
    end else begin
        if (push) begin
            queue <= {queue[2*`SIZE-5:0], push_data};
            if (pop) begin
                index <= index + 1;
            end else begin
                index <= index + 2;
            end
        end else begin
            if (pop) begin
                index <= index - 1;
            end
        end
        pop_data <= queue[2*(index-1)+:2];
    end
end

assign buffer = queue[31:0];
assign count = index;

endmodule

