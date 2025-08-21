module p2s_converter #(
    parameter WIDTH = 8   // default 8 bits, can override for 16/64, etc.
)(
    input  wire             clk,
    input  wire             rst,
    input  wire [WIDTH-1:0] data_in,
    output reg              bit_value
);

    reg [$clog2(WIDTH):0] bit_index;  // counter for current bit

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bit_index <= 0;
            bit_value <= 0;
        end else begin
            if (bit_index < WIDTH) begin
                bit_value <= data_in[bit_index];  // LSB-first
                bit_index <= bit_index + 1;
            end
        end
    end

endmodule
