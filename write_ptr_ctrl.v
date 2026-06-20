// write_ptr_ctrl.v
module write_ptr_ctrl #(
    parameter ADDR_WIDTH = 4
) (
    input  wire                wclk,
    input  wire                wrst_n,
    input  wire                winc,
    input  wire [ADDR_WIDTH:0] rgray_sync,   // synchronised read pointer (Gray)
    output reg  [ADDR_WIDTH:0] wbin,
    output reg  [ADDR_WIDTH:0] wgray,
    output wire [ADDR_WIDTH-1:0] waddr,
    output reg                 wfull
);

    wire [ADDR_WIDTH:0] wbin_next, wgray_next;
    wire full_next;

    // Next binary pointer (increment only if write enabled and not full)
    assign wbin_next = wbin + (winc & ~wfull);

    // Convert to Gray
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;

    // Memory address (lower ADDR_WIDTH bits)
    assign waddr = wbin[ADDR_WIDTH-1:0];

    // FULL detection: three conditions (Cummings paper)
    // 1. MSBs differ (wptr wrapped more times)
    // 2. 2nd MSBs differ (inverted 2nd MSB test)
    // 3. Remaining bits equal
    assign full_next = (wgray_next == {
        ~rgray_sync[ADDR_WIDTH:ADDR_WIDTH-1],
         rgray_sync[ADDR_WIDTH-2:0]
    });

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin  <= 0;
            wgray <= 0;
            wfull <= 0;
        end else begin
            wbin  <= wbin_next;
            wgray <= wgray_next;
            wfull <= full_next;   // registered output – pessimistic removal
        end
    end
endmodule