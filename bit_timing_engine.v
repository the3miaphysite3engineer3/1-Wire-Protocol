module bit_timing_engine (
    input  wire       clk,
    input  wire       rst,

    // Control interface
    input  wire [1:0] cmd,        // 00=IDLE, 01=RESET, 10=WRITE, 11=READ
    input  wire       write_bit,  // single bit to write when cmd=WRITE
    output reg        read_bit,   // latched read value or presence
    output reg        busy,       // engine active
    output reg        done,       // slot finished

    inout  wire       data        // 1-Wire bus
);

    // -------------------------------------------------------------------------
    // Timing parameters (1 tick = 1 µs @ 1 MHz clk)
    // -------------------------------------------------------------------------
    parameter integer T_SLOT   = 60;   // slot duration
    parameter integer T_LOW1   = 6;    // write '1' low
    parameter integer T_LOW0   = 60;   // write '0' low
    parameter integer T_RSTL   = 480;  // reset low
    parameter integer T_PDHIGH = 70;   // wait before presence detect
    parameter integer T_SAMPLE = 15;   // read sample time (after release)

    // Commands
    localparam CMD_IDLE  = 2'b00;
    localparam CMD_RESET = 2'b01;
    localparam CMD_WRITE = 2'b10;
    localparam CMD_READ  = 2'b11;

    // FSM states
    localparam S_IDLE = 3'd0,
               S_LOW  = 3'd1,
               S_REL  = 3'd2,
               S_WAIT = 3'd3,
               S_DONE = 3'd4;

    reg [2:0]  state, next;
    reg [15:0] counter;
    reg        data_drive;

    assign data = (data_drive) ? 1'b0 : 1'bz;  // open-drain driver

    // Sequential FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= S_IDLE;
            counter    <= 0;
            data_drive <= 0;
            busy       <= 0;
            done       <= 0;
            read_bit   <= 1'b1;  // bus idle = high
        end else begin
            state <= next;

            if (state != S_IDLE && state != S_DONE)
                counter <= counter + 1;
            else
                counter <= 0;

            // sample point during READ
            if (state == S_REL && cmd == CMD_READ && counter == T_SAMPLE) begin
                read_bit <= data;
            end

            // sample PRESENCE after RESET
            if (state == S_WAIT && cmd == CMD_RESET && counter == T_PDHIGH) begin
                read_bit <= ~data;  // 1 = slave present, 0 = no slave
            end
        end
    end

    // Combinational FSM
    always @(*) begin
        next       = state;
        data_drive = 0;
        busy       = 1;
        done       = 0;

        case (state)
            S_IDLE: begin
                busy = 0;
                case (cmd)
                    CMD_RESET: next = S_LOW;
                    CMD_WRITE: next = S_LOW;
                    CMD_READ:  next = S_LOW;
                endcase
            end

            // Drive bus low
            S_LOW: begin
                case (cmd)
                    CMD_WRITE: begin
                        data_drive = 1;
                        if ((!write_bit && counter >= T_LOW0) || 
                            ( write_bit && counter >= T_LOW1))
                            next = S_REL;
                    end
                    CMD_READ: begin
                        data_drive = 1;
                        if (counter >= 6) next = S_REL;
                    end
                    CMD_RESET: begin
                        data_drive = 1;
                        if (counter >= T_RSTL) next = S_REL;
                    end
                endcase
            end

            // Release bus
            S_REL: begin
                case (cmd)
                    CMD_WRITE: if (counter >= T_SLOT) next = S_DONE;
                    CMD_READ:  if (counter >= T_SLOT) next = S_DONE;
                    CMD_RESET: if (counter >= T_RSTL + T_PDHIGH) next = S_WAIT;
                endcase
            end

            // Wait for bus response (PRESENCE)
            S_WAIT: begin
                case (cmd)
                    CMD_RESET: if (counter >= T_RSTL + 240) next = S_DONE;
                endcase
            end

            // Operation complete
            S_DONE: begin
                done = 1;
                busy = 0;
                next = S_IDLE;
            end
        endcase
    end

endmodule
