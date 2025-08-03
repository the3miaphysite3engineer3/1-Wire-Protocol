module p2s_converter (
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire status,
    output reg bit_value
);
// Simple stub: output LSB of data_in
reg i;
initial begin
    i = 0;
end
always @(posedge clk or posedge rst) begin
    if (rst) bit_value <= 0;
    else begin
        if(last_bit_sent) begin
            i = i+1;
            bit_value = data_in[i];
        end
    end
end
endmodule