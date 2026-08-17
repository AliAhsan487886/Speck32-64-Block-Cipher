// =============================================================================
// tb_speck32_64.sv
//
// Self-checking testbench for speck32_64_top.
//
//   1. Applies the mandatory official test vector:
//        key       = 64'h1918_1110_0908_0100
//        plaintext = 32'h6574_694c
//        expected  = 32'ha868_42f2
//
//   2. Reads speck_test_vectors.txt (produced by golden_model.py -- the
//      required Python reference model) and applies each
//      "key plaintext ciphertext" hex triple to the DUT, using the
//      start/valid_out handshake.
//
//   3. Prints PASS/FAIL per vector and a final summary
//      (TOTAL / PASS / FAIL), matching the "self-checking testbench,
//      PASS + vector count summary" requirement.
//
// Run (from the directory containing all .sv files and
// speck_test_vectors.txt):
//   iverilog -g2012 -o sim speck_datapath.sv speck_controller.sv \
//            speck32_64_top.sv tb_speck32_64.sv
//   vvp sim
// =============================================================================

`timescale 1ns/1ps

module tb_speck32_64;

    // -------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------
    logic        clk;
    logic        rst_n;
    logic        start;
    logic [63:0] key_in;
    logic [31:0] plaintext;
    logic [31:0] ciphertext;
    logic        valid_out;

    speck32_64_top dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .key_in     (key_in),
        .plaintext  (plaintext),
        .ciphertext (ciphertext),
        .valid_out  (valid_out)
    );

    // -------------------------------------------------------------------
    // Clock: 10 ns period
    // -------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------
    // Scoreboard counters
    // -------------------------------------------------------------------
    int total_count = 0;
    int pass_count  = 0;
    int fail_count  = 0;

    // -------------------------------------------------------------------
    // Drive one operation through the start/valid_out handshake and
    // capture the resulting ciphertext.
    // -------------------------------------------------------------------
    localparam int TIMEOUT_CYCLES = 200;

    task automatic run_vector(
        input  logic [63:0] t_key,
        input  logic [31:0] t_pt,
        output logic [31:0] t_ct
    );
        int cycles;
        @(posedge clk);
        key_in    = t_key;
        plaintext = t_pt;
        start     = 1'b1;
        @(posedge clk);
        start     = 1'b0;

        // Poll for valid_out with a timeout so a broken DUT cannot hang
        // the simulation. Always advance at least one clock edge before
        // sampling: valid_out may still read as the *previous* vector's
        // leftover DONE-state value if checked in the same delta-cycle
        // as the start pulse, before the controller's state register
        // (updated via a nonblocking assignment on this same edge) has
        // actually settled.
        cycles = 0;
        do begin
            @(posedge clk);
            cycles++;
        end while (valid_out !== 1'b1 && cycles < TIMEOUT_CYCLES);
        if (valid_out !== 1'b1)
            $display("ERROR: TIMEOUT waiting for valid_out (key=%016h pt=%08h)", t_key, t_pt);

        t_ct = ciphertext;
    endtask

    // -------------------------------------------------------------------
    // Apply a vector, compare against expected, log PASS/FAIL.
    // -------------------------------------------------------------------
    task automatic check_vector(
        input string       label,
        input logic [63:0] t_key,
        input logic [31:0] t_pt,
        input logic [31:0] expected
    );
        logic [31:0] actual;
        run_vector(t_key, t_pt, actual);
        total_count++;
        if (actual === expected) begin
            pass_count++;
            $display("[PASS] %-10s key=%016h pt=%08h ct=%08h", label, t_key, t_pt, actual);
        end
        else begin
            fail_count++;
            $display("[FAIL] %-10s key=%016h pt=%08h expected=%08h got=%08h",
                      label, t_key, t_pt, expected, actual);
        end
    endtask

    // -------------------------------------------------------------------
    // Main stimulus
    // -------------------------------------------------------------------
    int          fd;
    int          scan_status;
    logic [63:0] v_key;
    logic [31:0] v_pt, v_ct;
    int          vec_idx;

    initial begin
        // Reset
        rst_n     = 1'b0;
        start     = 1'b0;
        key_in    = '0;
        plaintext = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        $display("====================================================");
        $display(" SPECK32/64 self-checking testbench");
        $display("====================================================");

        // -----------------------------------------------------------
        // 1) Mandatory official test vector
        // -----------------------------------------------------------
        check_vector("OFFICIAL", 64'h1918_1110_0908_0100, 32'h6574_694c, 32'ha868_42f2);

        // -----------------------------------------------------------
        // 2) Random vectors generated by golden_model.py
        // -----------------------------------------------------------
        fd = $fopen("speck_test_vectors.txt", "r");
        if (fd == 0) begin
            $display("WARNING: speck_test_vectors.txt not found -- run golden_model.py first. Skipping random vectors.");
        end
        else begin
            vec_idx = 0;
            while (!$feof(fd)) begin
                scan_status = $fscanf(fd, "%h %h %h\n", v_key, v_pt, v_ct);
                if (scan_status == 3) begin
                    vec_idx++;
                    check_vector($sformatf("RAND_%0d", vec_idx), v_key, v_pt, v_ct);
                end
            end
            $fclose(fd);
        end

        // -----------------------------------------------------------
        // Summary
        // -----------------------------------------------------------
        $display("====================================================");
        $display(" TOTAL=%0d  PASS=%0d  FAIL=%0d", total_count, pass_count, fail_count);
        if (fail_count == 0)
            $display(" RESULT: ALL VECTORS PASSED");
        else
            $display(" RESULT: %0d VECTOR(S) FAILED", fail_count);
        $display("====================================================");

        $finish;
    end

endmodule
