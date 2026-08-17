// =============================================================================
// speck_controller.sv
//
// SPECK32/64 controller FSM.
//
// Sequences the datapath through: reset -> load -> 22 rounds -> output-valid
// -> ready for next operation, per the required start/valid_out handshake.
//
// States:
//   IDLE  - waiting for start. load_en=0, round_en=0, valid_out=0.
//           self-loops while start==0; on start==1 -> LOAD.
//   LOAD  - one cycle. load_en=1: datapath latches key_in/plaintext and
//           clears round_cnt. Unconditional -> ROUND.
//   ROUND - round_en=1 every cycle. Datapath advances one round per clock
//           and increments round_cnt (0..21). Self-loops while
//           last_round==0 (i.e. round_cnt < 21). When last_round==1, the
//           22nd (final) round is still executed this cycle, and the FSM
//           moves to DONE next cycle. Total: exactly 22 cycles in ROUND.
//   DONE  - valid_out=1, ciphertext held stable on X_reg/Y_reg (round_en=0
//           so the datapath does not advance further). Self-loops while
//           start==0; on start==1 -> LOAD (accepts the next operation
//           directly, re-arming the pipeline for back-to-back encryptions).
//
// Inputs:
//   clk, rst_n, start  - external handshake signals
//   last_round         - status from datapath (round_cnt == 21)
//
// Outputs (drive the datapath's control ports and the top-level valid_out):
//   load_en, round_en, valid_out
// =============================================================================

module speck_controller (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic last_round,

    output logic load_en,
    output logic round_en,
    output logic valid_out
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        LOAD  = 2'b01,
        ROUND = 2'b10,
        DONE  = 2'b11
    } state_t;

    state_t state, next_state;

    // -------------------------------------------------------------------
    // State register
    // -------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // -------------------------------------------------------------------
    // Next-state logic
    // -------------------------------------------------------------------
    always_comb begin
        next_state = state;
        unique case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else       next_state = IDLE;
            end
            LOAD: next_state = ROUND;
            ROUND: begin
                if (last_round) next_state = DONE;
                else            next_state = ROUND;
            end
            DONE: begin
                if (start) next_state = LOAD;
                else       next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------------------
    // Output logic (Moore -- outputs depend only on current state)
    // -------------------------------------------------------------------
    always_comb begin
        load_en   = 1'b0;
        round_en  = 1'b0;
        valid_out = 1'b0;
        unique case (state)
            IDLE:  ; // all outputs 0
            LOAD:  load_en   = 1'b1;
            ROUND: round_en  = 1'b1;
            DONE:  valid_out = 1'b1;
            default: ;
        endcase
    end

endmodule
