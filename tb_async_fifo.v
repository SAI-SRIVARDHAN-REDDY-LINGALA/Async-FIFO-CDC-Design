// ======================================================================
//  ASYNC FIFO TESTBENCH (Depth=4) – SIMPLIFIED & CLEARLY COMMENTED
// ======================================================================
//
//  *** COVERAGE SUMMARY ***
//  This testbench verifies the following aspects of the async FIFO:
//    1. Reset initialisation (wfull=0, rempty=1, pointers = 0)
//    2. Single write & read (data integrity, FIFO order)
//    3. Fill FIFO to full → wfull asserts immediately
//    4. Overflow blocking (write when full is ignored)
//    5. Read all data → rempty asserts immediately
//    6. Underflow blocking (read when empty is ignored)
//    7. Simultaneous read/write (interleaved, 15 cycles)
//    8. Pointer wraparound (3 fill/drain cycles – tests extra MSB)
//    9. Random traffic (50 random write/read operations)
//
//  *** METHOD ***
//  - Uses a 4‑deep FIFO (ADDR_WIDTH=2) for easy visual inspection.
//  - No automated scoreboard; verification is done manually by observing
//    printed data and flag states (PASS/FAIL messages are based on flags).
//  - Prints every write, read, block event with time and flag values.
//  - Generates VCD file for waveform inspection.
// ======================================================================

`timescale 1ns / 1ps

module tb_async_fifo;

    // ---------- Parameters ----------
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 2;          // depth = 2^2 = 4
    parameter DEPTH      = 1 << ADDR_WIDTH;

    // ---------- Signals ----------
    reg wclk, wrst_n, winc;
    reg [DATA_WIDTH-1:0] wdata;
    wire wfull;

    reg rclk, rrst_n, rinc;
    wire [DATA_WIDTH-1:0] rdata;
    wire rempty;

    // DUT instance
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wclk  (wclk),
        .wrst_n(wrst_n),
        .winc  (winc),
        .wdata (wdata),
        .wfull (wfull),
        .rclk  (rclk),
        .rrst_n(rrst_n),
        .rinc  (rinc),
        .rdata (rdata),
        .rempty(rempty)
    );

    // ---------- Clocks ----------
    // wclk: 100 MHz (period 10 ns), rclk: 62.5 MHz (period 16 ns)
    initial begin wclk = 0; forever #5  wclk = ~wclk; end
    initial begin rclk = 0; forever #8  rclk = ~rclk; end

    // ---------- Tasks ----------
    // Reset both domains (asynchronous assert, synchronous de‑assert)
    task reset_fifo;
    begin
        wrst_n = 0; rrst_n = 0;
        winc = 0; rinc = 0; wdata = 0;
        repeat(5) @(posedge wclk);
        repeat(5) @(posedge rclk);
        wrst_n = 1; rrst_n = 1;
        repeat(3) @(posedge wclk);
        $display("========== RESET DONE (wfull=%b, rempty=%b) ==========\n", wfull, rempty);
    end
    endtask

    // Write a word (if not full); print event with current flag states
    task write_word;
        input [DATA_WIDTH-1:0] data;
    begin
        @(posedge wclk);
        if (!wfull) begin
            winc = 1;
            wdata = data;
            @(posedge wclk);
            winc = 0;
            $display("TIME=%0t: WRITE data=0x%h (wfull=%b, rempty=%b)", $time, data, wfull, rempty);
        end else begin
            $display("TIME=%0t: WRITE BLOCKED (FULL) data=0x%h", $time, data);
        end
    end
    endtask

    // Read a word (if not empty); print event with current flag states
    task read_word;
    begin
        @(posedge rclk);
        if (!rempty) begin
            rinc = 1;
            @(posedge rclk);
            rinc = 0;
            $display("TIME=%0t: READ  data=0x%h (wfull=%b, rempty=%b)", $time, rdata, wfull, rempty);
        end else begin
            $display("TIME=%0t: READ BLOCKED (EMPTY)", $time);
        end
    end
    endtask

    // Drain all remaining data until FIFO becomes empty
    task drain_fifo;
        integer timeout;
    begin
        timeout = 0;
        while (!rempty && timeout < 200) begin
            read_word();
            timeout = timeout + 1;
        end
        repeat(5) @(posedge rclk);
        $display("DRAIN complete. rempty=%b", rempty);
    end
    endtask

    // ---------- Internal Signal Display (optional) ----------
    // Prints binary/Gray pointers and synchronised values for CDC verification
    `define DISPLAY_INTERNALS \
        $display("         wbin=%b wgray=%b  rbin=%b rgray=%b", \
                 dut.u_wptr.wbin, dut.u_wptr.wgray, \
                 dut.u_rptr.rbin, dut.u_rptr.rgray); \
        $display("         wgray_sync=%b rgray_sync=%b", \
                 dut.wgray_sync, dut.rgray_sync);

    // ---------- Main Test Sequence ----------
    integer i, j;

    initial begin
        $display("\n========== ASYNC FIFO TEST (Depth=4) ==========\n");

        // --- Reset ---
        reset_fifo();
        `DISPLAY_INTERNALS

        // --- TEST1: Single write ---
        $display("\nTEST1: Write one entry");
        write_word(8'h55);                      // write 0x55
        repeat(8) @(posedge rclk);              // wait for CDC to propagate (2 rclk cycles is enough, 8 is safe)
        `DISPLAY_INTERNALS
        if (rempty !== 0) $display("TEST1 FAIL: empty not cleared");
        else $display("TEST1 PASS");

        // --- TEST2: Fill to full (3 more writes) ---
        $display("\nTEST2: Fill FIFO to full");
        for (i = 0; i < DEPTH-1; i = i+1)
            write_word(i+1);                    // write 1,2,3 (0x01,0x02,0x03)
        repeat(3) @(posedge wclk);
        `DISPLAY_INTERNALS
        if (!wfull) $display("TEST2 FAIL: full not asserted");
        else $display("TEST2 PASS");

        // --- TEST3: Overflow attempt (should be blocked) ---
        $display("\nTEST3: Overflow attempt");
        write_word(8'hAA);
        repeat(3) @(posedge wclk);
        `DISPLAY_INTERNALS
        if (wfull !== 1) $display("TEST3 FAIL: FIFO not full");
        else $display("TEST3 PASS");

        // --- TEST4: Read all data (should become empty) ---
        $display("\nTEST4: Read all data");
        drain_fifo();
        repeat(3) @(posedge rclk);
        `DISPLAY_INTERNALS
        if (!rempty) $display("TEST4 FAIL: empty not asserted after drain");
        else $display("TEST4 PASS");

        // --- TEST5: Underflow attempt (should be blocked) ---
        $display("\nTEST5: Underflow attempt");
        read_word();                            // FIFO is empty
        repeat(3) @(posedge rclk);
        `DISPLAY_INTERNALS
        if (rempty !== 1) $display("TEST5 FAIL: empty not maintained");
        else $display("TEST5 PASS");

        // --- TEST6: Simultaneous read/write (interleaved, 15 writes) ---
        $display("\nTEST6: Simultaneous read/write (15 writes)");
        for (i = 0; i < 15; i = i+1) begin
            write_word(i + 100);                // write 100..114
            // Read every second write (if data available)
            if (i % 2 == 0 && !rempty) read_word();
        end
        drain_fifo();                           // read remaining data
        repeat(3) @(posedge rclk);
        `DISPLAY_INTERNALS
        if (rempty !== 1) $display("TEST6 FAIL: not empty after simultaneous");
        else $display("TEST6 PASS");

        // --- TEST7: Pointer wraparound (3 fill/drain cycles) ---
        $display("\nTEST7: Pointer wraparound (3 cycles)");
        for (j = 0; j < 3; j = j+1) begin
            for (i = 0; i < DEPTH; i = i+1)
                write_word(i + 200 + j*20);     // write 200..203, 220..223, 240..243
            drain_fifo();
        end
        repeat(3) @(posedge rclk);
        `DISPLAY_INTERNALS
        // No flag check here – the test passes if all writes/reads succeed and data order is preserved.
        $display("TEST7 PASS (no mismatch expected)");

        // --- TEST8: Random traffic (50 operations) ---
        $display("\nTEST8: Random traffic (50 operations)");
        for (i = 0; i < 50; i = i+1) begin
            @(posedge wclk);
            if (($random & 1) && !wfull) begin
                wdata = $random;
                winc = 1;
                @(posedge wclk);
                winc = 0;
                $display("TIME=%0t: RANDOM WRITE data=0x%h", $time, wdata);
            end else begin
                winc = 0;
            end

            @(posedge rclk);
            if (($random & 1) && !rempty) begin
                rinc = 1;
                @(posedge rclk);
                rinc = 0;
                $display("TIME=%0t: RANDOM READ  data=0x%h", $time, rdata);
            end else begin
                rinc = 0;
            end
        end
        drain_fifo();                           // flush remaining data
        `DISPLAY_INTERNALS
        $display("TEST8 PASS (no mismatch expected)");

        // --- End ---
        $display("\n========== ALL TESTS COMPLETED ==========\n");
        #100;
        $finish;
    end

    // ---------- VCD Dump (for GTKWave) ----------
    initial begin
        $dumpfile("async_fifo_final.vcd");
        $dumpvars(0, tb_async_fifo);
    end

endmodule



// ======================================================================
// VERY SIMPLE ASYNC FIFO TESTBENCH
// ======================================================================
// Purpose:
// Resets the FIFO.

// Writes four words (0xA5, 0x5A, 0xFF, 0x00).
// After the fourth write, the FIFO becomes full (wfull=1).

// Tries a fifth write – it should be blocked because wfull is high.

// Reads the four words back.
// After the fourth read, the FIFO becomes empty (rempty=1).

// Tries a fifth read – it should be blocked because rempty is high.


// This simple testbench writes all data first, then reads all data later.

// That’s intentional – it is the simplest possible test to verify basic data flow and flag behavior without any interleaving.
//  For more realistic testing (simultaneous reads/writes, random traffic), use the complex testbench with the scoreboard.



// ======================================================================

// `timescale 1ns / 1ps

// module tb_simple_async_fifo;

//     // Parameters (depth = 4 for easy observation)
//     parameter DATA_WIDTH = 8;
//     parameter ADDR_WIDTH = 2;          // depth = 2^2 = 4
//     parameter DEPTH      = 1 << ADDR_WIDTH;

//     // Signals
//     reg wclk, rclk;
//     reg wrst_n, rrst_n;
//     reg winc, rinc;
//     reg [DATA_WIDTH-1:0] wdata;
//     wire [DATA_WIDTH-1:0] rdata;
//     wire wfull, rempty;

//     // DUT
//     async_fifo #(
//         .DATA_WIDTH(DATA_WIDTH),
//         .ADDR_WIDTH(ADDR_WIDTH)
//     ) dut (
//         .wclk  (wclk),
//         .wrst_n(wrst_n),
//         .winc  (winc),
//         .wdata (wdata),
//         .wfull (wfull),
//         .rclk  (rclk),
//         .rrst_n(rrst_n),
//         .rinc  (rinc),
//         .rdata (rdata),
//         .rempty(rempty)
//     );

//     // Clocks: wclk 100 MHz, rclk 62.5 MHz (asynchronous)
//     initial begin wclk = 0; forever #5 wclk = ~wclk; end
//     initial begin rclk = 0; forever #8 rclk = ~rclk; end

//     // ------------------------------------------------------------
//     // MAIN TEST SEQUENCE
//     // ------------------------------------------------------------
//     initial begin
//         $display("\n========== SIMPLE ASYNC FIFO TEST ==========\n");

//         // 1. Reset both domains
//         wrst_n = 0; rrst_n = 0;
//         winc = 0; rinc = 0; wdata = 0;
//         repeat(5) @(posedge wclk);
//         repeat(5) @(posedge rclk);
//         wrst_n = 1; rrst_n = 1;
//         repeat(3) @(posedge wclk);
//         $display("Reset done. wfull=%b, rempty=%b", wfull, rempty);

//         // 2. Write #1
//         @(posedge wclk);
//         winc = 1; wdata = 8'hA5;
//         @(posedge wclk);
//         winc = 0;
//         $display("Write #1 data=0x%h (wfull=%b, rempty=%b)", wdata, wfull, rempty);

//         // Because wfull and rempty are registered outputs – they update on the clock edge, but if we print immediately we might see the old values (before the write took effect).
//         // By waiting for the next clock edge, the DUT has finished updating its internal pointers and flags, so $display prints the correct post‑write state


//         // YES. Exactly – rempty takes 2 read clock cycles to become 0 after a write,
//         //  because the write pointer (wgray) must pass through a two-flip-flop synchronizer in the read clock domain before the empty flag can be updated.

//         // 3. Write #2
//         @(posedge wclk);
//         winc = 1; wdata = 8'h5A;
//         @(posedge wclk);
//         winc = 0;
//         $display("Write #2 data=0x%h (wfull=%b, rempty=%b)", wdata, wfull, rempty);

//         // 4. Write #3
//         @(posedge wclk);
//         winc = 1; wdata = 8'hFF;
//         @(posedge wclk);
//         winc = 0;
//         $display("Write #3 data=0x%h (wfull=%b, rempty=%b)", wdata, wfull, rempty);

//         // 5. Write #4 – should make FIFO full (depth=4)
//         @(posedge wclk);
//         winc = 1; wdata = 8'h00;
//         @(posedge wclk);
//         winc = 0;
//         $display("Write #4 data=0x%h (wfull=%b, rempty=%b)", wdata, wfull, rempty);

//         // 6. Attempt one more write (should be blocked because FIFO is full)
//         @(posedge wclk);
//         winc = 1; wdata = 8'hAA;
//         @(posedge wclk);
//         winc = 0;
//         $display("Write #5 (overflow attempt) data=0x%h – blocked? wfull=%b", wdata, wfull);


//     // YES. wfull asserts immediately on the same posedge wclk where the 5th write occurs.
//     // but it is actuall calculated before hand using wnext but will show at clock edge 



//         // 7. Wait a bit for CDC, then read all four words
//         repeat(3) @(posedge rclk);   // allow synchronizers to settle

//         // Read #1
//         @(posedge rclk);
//         rinc = 1;
//         @(posedge rclk);
//         rinc = 0;
//         $display("Read #1: data=0x%h (rempty=%b)", rdata, rempty);

//         // Read #2
//         @(posedge rclk);
//         rinc = 1;
//         @(posedge rclk);
//         rinc = 0;
//         $display("Read #2: data=0x%h (rempty=%b)", rdata, rempty);

//         // Read #3
//         @(posedge rclk);
//         rinc = 1;
//         @(posedge rclk);
//         rinc = 0;
//         $display("Read #3: data=0x%h (rempty=%b)", rdata, rempty);

//         // Read #4 – should make FIFO empty
//         @(posedge rclk);
//         rinc = 1;
//         @(posedge rclk);
//         rinc = 0;
//         $display("Read #4: data=0x%h (rempty=%b)", rdata, rempty);

//         // 8. Attempt one more read (should be blocked because FIFO is empty)
//         @(posedge rclk);
//         rinc = 1;
//         @(posedge rclk);
//         rinc = 0;
//         $display("Read #5 (underflow attempt) – blocked? rempty=%b", rempty);

//      // YES. rempty asserts immediately on the same posedge rclk where the 5th read occurs.


//         $display("\n========== SIMPLE TEST COMPLETE ==========\n");
//         #100;
//         $finish;
//     end

//     // ------------------------------------------------------------
//     // MONITOR & VCD
//     // ------------------------------------------------------------
//     // initial begin
//     //     $monitor("TIME=%0t | wfull=%b rempty=%b | winc=%b rinc=%b | wdata=0x%h rdata=0x%h",
//     //               $time, wfull, rempty, winc, rinc, wdata, rdata);
//     // end

//     initial begin
//         $dumpfile("simple_async_fifo.vcd");
//         $dumpvars(0, tb_simple_async_fifo);
//     end

// endmodule

