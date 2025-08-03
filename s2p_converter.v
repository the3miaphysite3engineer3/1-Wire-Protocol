module s2p_converter (
    input wire clk,
    input wire rst,
    input wire bit_value,
    input wire status,
    output reg [7:0] data_out
);

reg i;
initial begin
    data_out = 0;
    i = 0;
end

always @(posedge clk or posedge rst) begin
    if(rst) data_out <= 8'b00000000;
    else(i<=7) begin
        data_out[i] <= bit_value;
        i=i+1;
    end
end
    
endmodule