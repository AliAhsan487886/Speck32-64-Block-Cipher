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

    logic [15:0] x_reg, y_reg;
    logic [15:0] rk_reg;
    logic [15:0] l0_reg, l1_reg, l2_reg;
    logic [4:0]  round_cnt;   // 0 .. 21 fits comfortably in 5 bits

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

    assign last_round = (round_cnt == 5'd21);

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

    assign ciphertext = {x_reg, y_reg};

endmodule
