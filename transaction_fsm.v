module transaction_fsm (
    input wire clk,
    input wire rst,
    input wire [1:0] cmd,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    output reg [7:0] status
);

parameter WRITE = 2'b00;
parameter READ = 2'b01;
parameter RESET = 2'b10;
parameter PRESENCE = 3'b11;

reg[7:0] read_data;
reg current_bit;
reg status;

initial begin
    read_data = 8'b00000000;
    current_bit = 1'b0;
    status = 1'b0;
end

// Simple stub: set presence on reset command
always @(posedge clk or posedge rst) begin
    if (rst) begin
        data_out <= 8'b00000000;
        status <= 8'b00000000;
    end else begin
        case (cmd)
            WRITE: 
                crc8_unit crc();
                p2s_converter p2s(.clk(clk), .rst(rst), .data_in(data_in), .bit_value(current_bit), .status(status_sent));
                bit_timing_engine bit(.clk(clk), .rst(rst), .data(current_bit), .status(status));
            READ:
                bit_timing_engine bit(.clk(clk), .rst(rst), .data(current_bit), .status(status));
                s2p_converter s2p(.clk(clk), .rst(rst), .status(status_received), .data_out(data_out));
                    
                crc8_unit crc();
            PRESENCE:
                bit_timing_engine bit();
            RESET:
                bit_timing_engine bit();

        endcase
    end
end
endmodule