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
    uio_in[7]  - pulse a 1 to write ui_in to AAAAA addr, set to 0 to indicate reading
    uio_in[6]  - pulse a 1 to switch to COMPUTE mode
    AAAAA      - set to the address to write to or read from. When reading,
                 the highest bit indicates whether that's an orbit length (0)
                 or a path record (1), when writing, the highest bit is
                 ignored.

*/

module collatz (
    input  state,
    input  [BITS_IDX:0] iter,
    input  [BITS_IDX:0] orbit_len,
    input  [BITS_IDX:0] path_record,
    input was_overflow,
    output busy,
    output [BITS_IDX:0] next_iter,
    output [BITS_IDX:0] next_orbit_len,
    output [BITS_IDX:0] next_path_record,
    output next_overflows
);
    wire is_even = !iter[0];
    wire comp = state == STATE_COMPUTE;
    wire [1:0] overflow_bits;

    assign {overflow_bits, next_iter} = is_even ?
                                        iter >> 1 :
                                        (iter << 1) + iter + 1;
    assign next_overflows = was_overflow || overflow_bits != 2'b00;

    // XXX: this is a hack: I'm comparing to 2 here to compensate for an
    // off-by-one bug that I don't understand yet
    assign busy = iter != 2 && !was_overflow;

    assign next_orbit_len = comp ? orbit_len + 1 : orbit_len;
    assign next_path_record = next_iter > path_record ? next_iter : path_record;
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
    reg [BITS_IDX:0] iter;
    reg [BITS_IDX:0] orbit_len;
    reg [BITS_IDX:0] path_record;

    wire [BITS_IDX:0] next_iter;
    wire [BITS_IDX:0] next_orbit_len;
    wire [BITS_IDX:0] next_path_record;
    wire next_overflows;

    localparam IOCTL_COMPUTE = 8'h80;
    localparam IOCTL_IO = 8'h00;

    reg state;          // 0 - IO, 1 - COMPUTE
    reg overflow;
    wire compute_busy;
    reg [7:0] ioctl;

    assign uio_oe = ioctl;
    assign uio_out = {compute_busy, 7'b0};

    wire [7:0] data_in;
    reg [7:0] data_out;
    wire state_bit;
    wire write_enable;
    wire [ADDR_IDX:0] addr;
    wire read_path_record;
    wire switch_to_compute;
    wire switch_to_io;

    always @(posedge clk)
    begin
        if (reset) begin
            state <= 0;
            ioctl <= IOCTL_IO;
            num <= 0;
            data_out <= 0;
            orbit_len <= 0;
            path_record <= 0;
            overflow <= 0;
        end else begin
            if (switch_to_compute) begin
                ioctl <= IOCTL_COMPUTE;
                state <= STATE_COMPUTE;
                iter <= num;
                path_record <= num;
            end
            if (switch_to_io) begin
                ioctl <= IOCTL_IO;
                state <= STATE_IO;
                if (overflow) begin
                    path_record <= 32'hbaadf00d;
                end
            end
            case (state)
                STATE_IO: begin
                    if (write_enable) begin
                        num[addr*8 +: 8] <= data_in;
                    end else begin
                        if (read_path_record) begin
                            data_out <= path_record[addr*8 +: 8];
                        end else begin
                            data_out <= orbit_len[addr*8 +: 8];
                        end
                    end
                end
                STATE_COMPUTE: begin
                    iter <= next_iter;
                    orbit_len <= next_orbit_len;
                    path_record <= next_path_record;
                    overflow <= next_overflows;
                end
            endcase
        end
    end

    assign switch_to_compute = !reset && state_bit && state == STATE_IO && !overflow;
    assign switch_to_io = !reset && !compute_busy && state == STATE_COMPUTE || overflow;

    collatz collatz(
        .state(state),
        .iter(iter),
        .orbit_len(orbit_len),
        .path_record(path_record),
        .was_overflow(overflow),
        .busy(compute_busy),
        .next_iter(next_iter),
        .next_orbit_len(next_orbit_len),
        .next_path_record(next_path_record),
        .next_overflows(next_overflows)
    );

    assign data_in = ui_in;
    assign uo_out = data_out;
    assign state_bit = uio_in[6];
    assign write_enable = uio_in[7];
    assign addr = uio_in[ADDR_IDX:0];
    assign read_path_record = uio_in[4];
endmodule
