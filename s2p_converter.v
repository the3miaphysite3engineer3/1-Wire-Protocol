module s2p_converter #(
    parameter WIDTH = 16   // default = 16 bits, can be overridden
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              bit_value,
    output reg  [WIDTH-1:0]  data_out
);

    reg [$clog2(WIDTH):0] bit_index;  // enough bits to count WIDTH

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_out  <= {WIDTH{1'b0}};
            bit_index <= 0;
        end else begin
            if (bit_index < WIDTH) begin
                data_out[bit_index] <= bit_value;  // LSB-first shifting
                bit_index <= bit_index + 1;
            end
        end
    end

endmodule
