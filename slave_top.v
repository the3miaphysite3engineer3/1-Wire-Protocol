module slave_top(
    input  wire clk,
    input  wire rst,
    input  wire [2:0] cmd,
    input  wire [7:0] data_in,
    output wire [63:0] data_out,
    output wire [7:0]  status,
    inout  wire        onewire_bus
);

    transaction_fsm #(.ROLE("SLAVE")) slave_fsm (
        .clk(clk),
        .rst(rst),
        .cmd(cmd),
        .data_in(data_in),
        .data_out(data_out),
        .status(status),
        .data(onewire_bus)
    );

endmodule
