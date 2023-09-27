`default_nettype none

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
    reg [7:0] out;

    assign uio_oe[7:0] = {8{1'b0}}; // BIDIRECTIONAL path set to input
    assign uio_out[7:0] = {8{1'b0}}; // Initialise unused outputs of the BIDIRECTIONAL path to 0 for posterity (otherwise Yosys fails)

    always @(posedge clk or posedge reset)
    begin
        if (reset) begin
            out <= 0;
        end else begin
            out <= 8'hff;
        end
    end

    assign uo_out = out;
endmodule
