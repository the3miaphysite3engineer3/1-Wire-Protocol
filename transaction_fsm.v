module transaction_fsm #(
    parameter ROLE   = "MASTER",
    parameter ROM    = 64'hA1B2_C3D4_E5F6_1234
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] cmd,        // 3-bit command bus
    input  wire [7:0] data_in,
    output reg  [63:0] data_out,  // 64-bit max (ROM or data+CRC)
    output reg  [7:0] status,
    inout  wire       data        // 1-Wire bus
);

    // Commands
    localparam WRITE     = 3'b000;
    localparam READ      = 3'b001;
    localparam RESET     = 3'b010;
    localparam PRESENCE  = 3'b011;
    localparam READ_ROM  = 3'b100;
    localparam SEND_ROM  = 3'b101;

    // Internal wires
    wire        current_bit_wr;
    wire        current_bit_rd;
    wire [7:0]  crc_value;
    wire        crc_ok;
    wire        busy_wr, done_wr;
    wire        busy_rd, done_rd;
    wire        busy_rst, done_rst;
    wire        busy_rom, done_rom;
    wire        bit_from_bus;

    // Internal wires for submodule outputs (fix for reg conflict)
    wire [7:0]  s2p_data_out;
    wire [63:0] s2p_rom_data_out;

    //---------------------------------------------------
    // WRITE datapath (always instantiated, gated by cmd)
    //---------------------------------------------------
    crc8_unit crc_wr (
        .clk(clk),
        .rst(rst),
        .mode(2'b10),       // WRITE
        .data_in(data_in),
        .crc_out(crc_value),
        .crc_ok(crc_ok)
    );

    p2s_converter p2s (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .bit_value(current_bit_wr)
    );

    bit_timing_engine bit_wr (
        .clk(clk),
        .rst(rst),
        .cmd( (cmd == WRITE) ? 2'b10 : 2'b00 ), // only active in WRITE
        .write_bit(current_bit_wr),
        .read_bit(),
        .busy(busy_wr),
        .done(done_wr),
        .data(data)
    );

    //---------------------------------------------------
    // READ datapath
    //---------------------------------------------------
    bit_timing_engine bit_rd (
        .clk(clk),
        .rst(rst),
        .cmd( (cmd == READ) ? 2'b11 : 2'b00 ),
        .write_bit(1'b1),
        .read_bit(current_bit_rd),
        .busy(busy_rd),
        .done(done_rd),
        .data(data)
    );

    s2p_converter s2p (
        .clk(clk),
        .rst(rst),
        .bit_value(current_bit_rd),
        .data_out(s2p_data_out)   // goes to wire, not reg
    );

    crc8_unit crc_rd (
        .clk(clk),
        .rst(rst),
        .mode(2'b11),              // READ
        .data_in(s2p_data_out),
        .crc_out(),
        .crc_ok(crc_ok)
    );

    //---------------------------------------------------
    // RESET / PRESENCE
    //---------------------------------------------------
    bit_timing_engine bit_rst (
        .clk(clk),
        .rst(rst),
        .cmd( (cmd == RESET || cmd == PRESENCE) ? 2'b01 : 2'b00 ),
        .write_bit(1'b1),
        .read_bit(bit_from_bus),
        .busy(busy_rst),
        .done(done_rst),
        .data(data)
    );

    //---------------------------------------------------
    // READ_ROM (only MASTER)
    //---------------------------------------------------
    generate
        if (ROLE == "MASTER") begin : GEN_READ_ROM
            bit_timing_engine bit_rom (
                .clk(clk),
                .rst(rst),
                .cmd( (cmd == READ_ROM) ? 2'b11 : 2'b00 ),
                .write_bit(1'b1),
                .read_bit(current_bit_rd),
                .busy(busy_rom),
                .done(done_rom),
                .data(data)
            );

            s2p_converter #(.WIDTH(64)) s2p_rom (
                .clk(clk),
                .rst(rst),
                .bit_value(current_bit_rd),
                .data_out(s2p_rom_data_out)   // goes to wire
            );
        end
    endgenerate

    //---------------------------------------------------
    // SEND_ROM (only SLAVE)
    //---------------------------------------------------
    generate
        if (ROLE == "SLAVE") begin : GEN_SEND_ROM
            reg [63:0] shift_reg;
            reg [5:0]  bit_cnt;
            reg        sending;

            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    shift_reg <= ROM;
                    bit_cnt   <= 0;
                    sending   <= 0;
                end else begin
                    if (!sending && cmd == SEND_ROM) begin
                        shift_reg <= ROM;
                        bit_cnt   <= 0;
                        sending   <= 1;
                    end else if (sending) begin
                        if (done_rom) begin
                            shift_reg <= {1'b0, shift_reg[63:1]};
                            bit_cnt   <= bit_cnt + 1;
                            if (bit_cnt == 63)
                                sending <= 0;
                        end
                    end
                end
            end

            assign current_bit_wr = shift_reg[0];

            bit_timing_engine bit_send_rom (
                .clk(clk),
                .rst(rst),
                .cmd( (cmd == SEND_ROM) ? 2'b10 : 2'b00 ),
                .write_bit(current_bit_wr),
                .read_bit(),
                .busy(busy_rom),
                .done(done_rom),
                .data(data)
            );
        end
    endgenerate

    //---------------------------------------------------
    // FSM outputs
    //---------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_out <= 64'b0;
            status   <= 8'b0;
        end else begin
            case (cmd)
                WRITE: begin
                    data_out <= {48'b0, data_in, crc_value};
                    status   <= {5'b0, done_wr, busy_wr, crc_ok};
                end
                READ: begin
                    data_out <= {56'b0, s2p_data_out}; // copy from wire
                    status   <= {5'b0, done_rd, busy_rd, crc_ok};
                end
                RESET: begin
                    status   <= {6'b0, done_rst, busy_rst};
                end
                PRESENCE: begin
                    status   <= {7'b0, ~bit_from_bus};
                end
                READ_ROM: begin
                    data_out <= s2p_rom_data_out; // copy from wire
                    status   <= {6'b0, done_rom, busy_rom};
                end
                SEND_ROM: begin
                    status   <= {6'b0, done_rom, busy_rom};
                end
                default: begin
                    data_out <= 64'b0;
                    status   <= 8'h00;
                end
            endcase
        end
    end

endmodule
