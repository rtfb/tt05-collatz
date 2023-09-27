`default_nettype none

parameter BITS = 32;
parameter BITS_IDX = BITS - 1;       // upper index of the workhorse register
parameter ADDR_BITS = 4;
parameter ADDR_IDX = ADDR_BITS - 1;  // upper index of address bits
parameter STATE_IO = 0;
parameter STATE_COMPUTE = 1;

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

module collatz (
    input  clk,
    input  reset,
    input  state,
    input  [BITS_IDX:0] number,
    output reg busy,
    output reg [BITS_IDX:0] orbit_len,
    output reg [BITS_IDX:0] path_record
);
    reg [BITS_IDX:0] iter;
    wire is_even = !iter[0];

    always @(posedge clk)
    begin
        if (reset) begin
            orbit_len <= 32'h00000000;
            path_record <= 0;
            iter <= 0;
            busy <= 0;
        end

        if (state == STATE_COMPUTE) begin
            if (is_even) begin
                iter <= iter >> 1;
            end else begin
                iter <= (iter << 1) + iter + 1;
            end

            if (iter > path_record) begin
                path_record <= iter;
            end

            if (iter == 1) begin
                busy <= 0;
            end
            orbit_len <= orbit_len + 1;
        end
    end

    always @(posedge state)
    begin
        iter <= number;
        busy <= 1;
    end
endmodule

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
    reg [BITS_IDX:0] num;
    reg [BITS_IDX:0] orbit_len;
    reg [BITS_IDX:0] path_record;

    localparam IOCTL_COMPUTE = 8'h80;
    localparam IOCTL_IO = 8'h00;

    reg state;          // 0 - IO, 1 - COMPUTE
    wire compute_busy;
    reg [7:0] ioctl;

    assign uio_oe = ioctl;
    assign uio_out = {compute_busy, 7'b0};

    wire [7:0] data_in;
    reg [7:0] data_out;
    wire state_bit;
    wire iomode_bit;
    wire [ADDR_IDX:0] addr;
    wire read_path_record;

    always @(posedge clk)
    begin
        if (reset) begin
            state <= 0;
            ioctl <= IOCTL_IO;
            num <= 0;
            data_out <= 0;
        end

        if (state == STATE_IO) begin
            if (state_bit) begin
                ioctl <= IOCTL_COMPUTE;
                state <= STATE_COMPUTE;
            end else begin
                if (iomode_bit) begin
                    if (read_path_record) begin
                        data_out <= path_record[addr*8 +: 8];
                    end else begin
                        data_out <= orbit_len[addr*8 +: 8];
                    end
                end else begin
                    num[addr*8 +: 8] <= data_in;
                end
            end
        end
    end

    always @(negedge compute_busy)
    begin
        ioctl <= IOCTL_IO;
        state <= STATE_IO;
    end

    collatz collatz(
        .clk(clk),
        .reset(reset),
        .state(state),
        .number(num),
        .busy(compute_busy),
        .orbit_len(orbit_len),
        .path_record(path_record)
    );

    assign data_in = ui_in;
    assign uo_out = data_out;
    assign state_bit = uio_in[6];
    assign iomode_bit = uio_in[7];
    assign addr = uio_in[ADDR_IDX:0];
    assign read_path_record = uio_in[4];
endmodule
