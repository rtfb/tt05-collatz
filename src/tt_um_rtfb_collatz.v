`default_nettype none

parameter BITS = 32;
parameter ADDR_BITS = 5;
parameter ADDR_IDX = ADDR_BITS - 1;  // upper index of address bits

/*
The module can be in 2 states: IO, COMPUTE.
IO state has further 2 modes: INPUT and OUTPUT.
Bidirectional pins have different roles depending on the state:

COMPUTE
    uio_oe: 1xxx xxxx
    uio_out[7] - indicates whether the compute module is busy. When it becomes
                 0, the module will switch to the I/O mode, allowing to read
                 output and set a new input. All other bits are meaningless in
                 this mode.
IO
    uio_oe: 00xA AAAA
    uio_in[7]  - set to 0 to indicate writing, set to 1 to indicate reading
    uio_in[6]  - set to 1 to switch to COMPUTE mode
    AAAAA      - set to the address to write to or read from. When reading,
                 the highest bit indicates whether that's an orbit length (0)
                 or a path record (1), when writing, the highest bit is
                 ignored.

*/

// module collatz (
//     input  wire clk,
//     input  wire write_enable
// );
//     reg [BITS:0] num;
// endmodule

module tt_um_rtfb_collatz (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    wire reset = !rst_n;
    reg [BITS:0] num;

    localparam IOCTL_COMPUTE = 8'h80;
    localparam IOCTL_IO = 8'h00;
    localparam STATE_IO = 0;
    localparam STATE_COMPUTE = 1;

    reg state;          // 0 - IO, 1 - COMPUTE
    reg [7:0] ioctl;

    assign uio_oe = ioctl;
    assign uio_out[7:0] = {8{1'b0}}; // Initialise unused outputs of the BIDIRECTIONAL path to 0 for posterity (otherwise Yosys fails)

    wire [7:0] data_in;
    reg [7:0] data_out;
    wire state_bit;
    wire iomode_bit;
    wire [ADDR_IDX:0] addr;

    always @(posedge clk)
    begin
        if (reset) begin
            state <= 0;
            ioctl <= IOCTL_IO;
            num <= 0;
            data_out <= 0;
        end

        if (state == STATE_IO && state_bit) begin
            ioctl <= IOCTL_COMPUTE;
            state <= 1;
        end else begin
            ioctl <= IOCTL_IO;
            state <= 0;
        end

        if (iomode_bit) begin
            data_out <= num[addr*8 +: 8];
        end else begin
            num[addr[3:0]*8 +: 8] <= data_in;
        end
    end

//     collatz collatz(
//         .clk(clk),
//         .write_enable(write_enable)
//     );

    assign data_in = ui_in;
    assign uo_out = data_out;
    assign state_bit = uio_in[6];
    assign iomode_bit = uio_in[7];
    assign addr = uio_in[ADDR_IDX:0];
endmodule
