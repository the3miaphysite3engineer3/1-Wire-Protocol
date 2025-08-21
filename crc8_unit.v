module crc8_unit (
    input  wire       clk,
    input  wire       rst,
    input  wire [1:0] mode,
    input  wire [7:0] data_in,
    output reg  [7:0] crc_out,
    output reg        crc_ok
);

    localparam IDLE  = 2'b00;
    localparam RESET = 2'b01;
    localparam WRITE = 2'b10;
    localparam READ  = 2'b11;

    // Polynomial = x^8 + x^2 + x + 1 (0x07)
    localparam [7:0] POLY = 8'h07;

    reg [7:0] crc_reg;
    reg [7:0] crc_next;   // ✅ moved here
    integer i;            // ✅ moved here

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            crc_reg <= 8'h00;
            crc_out <= 8'h00;
            crc_ok  <= 1'b0;
        end 
        else begin
            case (mode)
                WRITE: begin
                    // Update CRC with incoming data
                    crc_next = crc_reg ^ data_in;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (crc_next[7])
                            crc_next = (crc_next << 1) ^ POLY;
                        else
                            crc_next = (crc_next << 1);
                    end
                    crc_reg <= crc_next;
                    crc_out <= crc_next;
                    crc_ok  <= 1'b0; // only check in READ mode
                end

                READ: begin
                    // In READ mode, we feed both data and the received CRC.
                    crc_next = crc_reg ^ data_in;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (crc_next[7])
                            crc_next = (crc_next << 1) ^ POLY;
                        else
                            crc_next = (crc_next << 1);
                    end
                    crc_reg <= crc_next;
                    crc_out <= crc_next;
                    // CRC OK when final remainder = 0
                    crc_ok  <= (crc_next == 8'h00);
                end
            endcase
        end
    end

endmodule
