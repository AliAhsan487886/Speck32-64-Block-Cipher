// =============================================================================
// speck32_64_top.sv
//
// Top-level SPECK32/64 encryption core. Port list is fixed by the project
// specification. Wires the controller (speck_controller) and datapath
// (speck_datapath) together:
//
//        start ---------------> +------------+   load_en    +-----------+
//                                | controller | -----------> | datapath  |
//   last_round <---------------- +------------+   round_en   |           |
//                                       |                    |           |
//                                       +--> valid_out        +---------->
//                                                              ciphertext
// =============================================================================

module speck32_64_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [63:0] key_in,      // {k3,k2,k1,k0}
    input  logic [31:0] plaintext,   // {x0,y0}
    output logic [31:0] ciphertext,
    output logic        valid_out
);

    // control lines between controller and datapath
    logic load_en;
    logic round_en;
    logic last_round;

    speck_controller u_controller (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .last_round (last_round),
        .load_en    (load_en),
        .round_en   (round_en),
        .valid_out  (valid_out)
    );

    speck_datapath u_datapath (
        .clk        (clk),
        .rst_n      (rst_n),
        .load_en    (load_en),
        .round_en   (round_en),
        .key_in     (key_in),
        .plaintext  (plaintext),
        .ciphertext (ciphertext),
        .last_round (last_round)
    );

endmodule
