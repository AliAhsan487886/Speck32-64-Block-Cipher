// =============================================================================
// speck_datapath.sv
//
// SPECK32/64 datapath.
//
// Architecture (see project write-up for justification):
//   Two structurally-identical round-function primitives run in parallel,
//   one per clock cycle, for 22 cycles:
//     - Encryption round unit : advances (X_reg, Y_reg) using the current
//                                round key RK_reg.
//     - Key schedule unit     : advances (L0/L1/L2_reg, RK_reg) on-the-fly,
//                                producing RK[i+1] one cycle ahead of when
//                                it is needed by the encryption unit.
//
//   Both primitives are the SAME wiring: ROTR7 -> ADD16 -> XOR -> ROTL2 -> XOR.
//   They are instantiated twice (rather than time-multiplexed through one
//   shared ALU) because SPECK32/64's word size (16 bits) makes a second
//   adder/rotator set essentially free in area, and running both units in
//   parallel keeps the controller to a single "ROUND" state with one round
//   completed per clock -- no extra muxing or extra latency is needed to
//   arbitrate a shared unit between the data round and the key expansion.
//
// Registers:
//   X_reg, Y_reg           - current cipher block words
//   RK_reg                 - current round key  (= RK[round_cnt])
//   L0_reg, L1_reg, L2_reg - 3-word sliding window of the key-schedule
//                            "l" sequence (oldest -> newest)
//   round_cnt              - 5-bit round index, 0 .. 21
//
// Control inputs (driven by speck_controller):
//   load_en   - synchronously loads all registers from key_in/plaintext
//               and clears round_cnt
//   round_en  - synchronously advances all registers by one round and
//               increments round_cnt
//
// Status output:
//   last_round - combinational flag, high when round_cnt == 21 (the
//                datapath is about to execute the final round this cycle)
// =============================================================================

module speck_datapath (
    input  logic        clk,
    input  logic        rst_n,

    // control inputs from speck_controller
    input  logic        load_en,
    input  logic        round_en,

    // operands
    input  logic [63:0] key_in,      // {k3,k2,k1,k0}
    input  logic [31:0] plaintext,   // {x0,y0}

    // results
    output logic [31:0] ciphertext,  // {x,y}
    output logic        last_round   // round_cnt == 21
);

    // -------------------------------------------------------------------
    // State registers
    // -------------------------------------------------------------------
    logic [15:0] x_reg, y_reg;
    logic [15:0] rk_reg;
    logic [15:0] l0_reg, l1_reg, l2_reg;
    logic [4:0]  round_cnt;   // 0 .. 21 fits comfortably in 5 bits

    // -------------------------------------------------------------------
    // Encryption round unit (combinational) -- primitive instance #1
    //   x_next = ( ROTR(x_reg,7) + y_reg ) XOR rk_reg
    //   y_next = ROTL(y_reg,2) XOR x_next
    // -------------------------------------------------------------------
    logic [15:0] rotr_x;      // ROTR7
    logic [15:0] sum_xy;      // ADD16
    logic [15:0] x_next;      // XOR_A
    logic [15:0] rotl_y;      // ROTL2
    logic [15:0] y_next;      // XOR_B

    assign rotr_x = {x_reg[6:0], x_reg[15:7]};       // fixed-wiring rotate right by 7
    assign sum_xy = rotr_x + y_reg;                  // mod 2^16 add, carry-out discarded
    assign x_next = sum_xy ^ rk_reg;
    assign rotl_y = {y_reg[13:0], y_reg[15:14]};     // fixed-wiring rotate left by 2
    assign y_next = rotl_y ^ x_next;

    // -------------------------------------------------------------------
    // Key schedule unit (combinational) -- primitive instance #2
    // structurally identical to the encryption unit above
    //   l3_next = ( ROTR(l0_reg,7) + rk_reg ) XOR round_cnt
    //   rk_next = ROTL(rk_reg,2) XOR l3_next
    // -------------------------------------------------------------------
    logic [15:0] rotr_l;      // ROTR7_k
    logic [15:0] sum_lrk;     // ADD16_k
    logic [15:0] l3_next;     // XOR_C  (this is l[i+3])
    logic [15:0] rotl_rk;     // ROTL2_k
    logic [15:0] rk_next;     // XOR_D  (this is RK[i+1])

    assign rotr_l  = {l0_reg[6:0], l0_reg[15:7]};    // fixed-wiring rotate right by 7
    assign sum_lrk = rotr_l + rk_reg;                // mod 2^16 add, carry-out discarded
    assign l3_next = sum_lrk ^ {11'b0, round_cnt};   // round_cnt zero-extended to 16 bits
    assign rotl_rk = {rk_reg[13:0], rk_reg[15:14]};  // fixed-wiring rotate left by 2
    assign rk_next = rotl_rk ^ l3_next;

    // -------------------------------------------------------------------
    // Status
    // -------------------------------------------------------------------
    assign last_round = (round_cnt == 5'd21);

    // -------------------------------------------------------------------
    // Sequential update
    // -------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg     <= '0;
            y_reg     <= '0;
            rk_reg    <= '0;
            l0_reg    <= '0;
            l1_reg    <= '0;
            l2_reg    <= '0;
            round_cnt <= '0;
        end
        else if (load_en) begin
            x_reg     <= plaintext[31:16];
            y_reg     <= plaintext[15:0];
            rk_reg    <= key_in[15:0];    // k0
            l0_reg    <= key_in[31:16];   // k1 -> l[0]
            l1_reg    <= key_in[47:32];   // k2 -> l[1]
            l2_reg    <= key_in[63:48];   // k3 -> l[2]
            round_cnt <= '0;
        end
        else if (round_en) begin
            x_reg     <= x_next;
            y_reg     <= y_next;
            rk_reg    <= rk_next;
            l0_reg    <= l1_reg;          // shift the 3-word sliding window
            l1_reg    <= l2_reg;
            l2_reg    <= l3_next;
            round_cnt <= round_cnt + 5'd1;
        end
        // else: hold (e.g. IDLE / DONE states in the controller)
    end

    // -------------------------------------------------------------------
    // Output
    // -------------------------------------------------------------------
    assign ciphertext = {x_reg, y_reg};

endmodule
