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

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

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
