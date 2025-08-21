`timescale 1ns/1ps

module tb_master_slave;

    reg clk, rst;
    reg [2:0] cmd_master;
    reg [7:0] din_master;
    wire [63:0] dout_master, dout_slave;
    wire [7:0]  status_master, status_slave;
    wire onewire_bus;

    // Master instance
    master_top UUT_MASTER (
        .clk(clk),
        .rst(rst),
        .cmd(cmd_master),
        .data_in(din_master),
        .data_out(dout_master),
        .status(status_master),
        .onewire_bus(onewire_bus)
    );

    // Slave instance
    slave_top UUT_SLAVE (
        .clk(clk),
        .rst(rst),
        .cmd(cmd_master),   // same cmd bus for simplicity
        .data_in(8'b0),
        .data_out(dout_slave),
        .status(status_slave),
        .onewire_bus(onewire_bus)
    );

    // Clock
    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1;
        cmd_master = 3'b000;
        din_master = 8'h00;
        #20 rst = 0;

        // Reset + presence
        $display("==== RESET + PRESENCE ====");
        cmd_master = 3'b010; #100;   // RESET
        cmd_master = 3'b011; #100;   // PRESENCE
        $display("Status Master: %b", status_master);
        $display("Status Slave : %b", status_slave);

        // READ_ROM from master
        $display("==== READ_ROM ====");
        cmd_master = 3'b100; #200;
        $display("Master got ROM: %h", dout_master);

        // SEND_ROM from slave
        $display("==== SEND_ROM ====");
        cmd_master = 3'b101; #200;
        $display("Slave sent ROM: %h", dout_slave);

        $stop;
    end

endmodule
