`default_nettype none

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
    uio_oe: 00AA AAAA
    uio_in[7]  - pulse a 1 to write ui_in to AAAAAA addr, set to 0 to indicate reading
    uio_in[6]  - pulse a 1 to switch to COMPUTE mode
    AAAAAA     - set to the address to write to or read from. When reading,
                 the highest bit indicates whether that's an orbit length (0)
                 or a path record (1), when writing, the highest bit is
                 ignored.
*/

parameter STATE_IO = 0;
parameter STATE_COMPUTE = 1;

// size of the Collatz orbit iterator
parameter BITS = 144;
parameter BITS_IDX = BITS - 1;

// size of a register for holding orbit length
parameter OLEN_BITS = 16;
parameter OLEN_BITS_IDX = OLEN_BITS - 1;

// size of a register for holding the upper bits of path record
parameter PLEN_BITS = 16;
parameter PLEN_BITS_IDX = OLEN_BITS - 1;

// width of the address bits
parameter ADDR_BITS = 5;
parameter ADDR_IDX = ADDR_BITS - 1;

module collatz (
    input  state,
    input  [BITS_IDX:0] iter,
    input  [OLEN_BITS_IDX:0] orbit_len,
    input  [PLEN_BITS_IDX:0] path_record_h16,
    output busy,
    output [BITS_IDX:0] next_iter,
    output [OLEN_BITS_IDX:0] next_orbit_len,
    output [PLEN_BITS_IDX:0] next_path_record
);
    wire is_even = !iter[0];
    wire comp = state == STATE_COMPUTE;
    assign next_iter = is_even ?
                       iter >> 1 :
                       (iter << 1) + iter + 1;

    // XXX: this is a hack: I'm comparing to 2 here to compensate for an
    // off-by-one bug that I don't understand yet.
    //
    // The check for orbit_len maxing out is a safeguard against a dead loop
    // due to potential unknown bugs.
    assign busy = iter != 2 && orbit_len != 16'hffff;

    wire [PLEN_BITS_IDX:0] next_iter_h16;
    assign next_iter_h16 = next_iter[BITS_IDX -: OLEN_BITS];
    assign next_orbit_len = comp ? orbit_len + 1 : orbit_len;
    assign next_path_record = comp && (next_iter_h16 > path_record_h16) ?
                              next_iter_h16 :
                              path_record_h16;
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
    reg [BITS_IDX:0] iter;
    reg [OLEN_BITS_IDX:0] orbit_len;
    reg [PLEN_BITS_IDX:0] path_record_h16;

    wire [BITS_IDX:0] next_iter;
    wire [OLEN_BITS_IDX:0] next_orbit_len;
    wire [PLEN_BITS_IDX:0] next_path_record;

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
    wire write_enable;
    wire [ADDR_IDX:0] addr;
    wire read_path_record;
    wire switch_to_compute;
    wire switch_to_io;

    always @(posedge clk)
    begin
        if (reset) begin
            state <= STATE_IO;
            ioctl <= IOCTL_IO;
            data_out <= 0;
            orbit_len <= 0;
            path_record_h16 <= 0;
        end else begin
            if (switch_to_compute) begin
                ioctl <= IOCTL_COMPUTE;
                state <= STATE_COMPUTE;
                path_record_h16 <= iter[BITS_IDX -: OLEN_BITS];
            end
            if (switch_to_io) begin
                ioctl <= IOCTL_IO;
                state <= STATE_IO;
            end
            case (state)
                STATE_IO: begin
                    if (write_enable) begin
                        iter[addr*8 +: 8] <= data_in;
                    end else begin
                        if (read_path_record) begin
                            data_out <= path_record_h16[addr*8 +: 8];
                        end else begin
                            data_out <= orbit_len[addr*8 +: 8];
                        end
                    end
                end
                STATE_COMPUTE: begin
                    iter <= next_iter;
                    orbit_len <= next_orbit_len;
                    path_record_h16 <= next_path_record;
                end
            endcase
        end
    end

    assign switch_to_compute = !reset && state_bit && state == STATE_IO;
    assign switch_to_io = !reset && !compute_busy && state == STATE_COMPUTE;

    collatz collatz(
        .state(state),
        .iter(iter),
        .orbit_len(orbit_len),
        .path_record_h16(path_record_h16),
        .busy(compute_busy),
        .next_iter(next_iter),
        .next_orbit_len(next_orbit_len),
        .next_path_record(next_path_record)
    );

    assign data_in = ui_in;
    assign uo_out = data_out;
    assign state_bit = uio_in[6];
    assign write_enable = uio_in[7];
    assign addr = uio_in[ADDR_IDX:0];
    assign read_path_record = uio_in[ADDR_IDX+1];
endmodule
