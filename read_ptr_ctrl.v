// read_ptr_ctrl.v
module read_ptr_ctrl #(
    parameter ADDR_WIDTH = 4
) (
    input  wire                rclk,
    input  wire                rrst_n,
    input  wire                rinc,
    input  wire [ADDR_WIDTH:0] wgray_sync,   // synchronised write pointer (Gray)
    output reg  [ADDR_WIDTH:0] rbin,
    output reg  [ADDR_WIDTH:0] rgray,
    output wire [ADDR_WIDTH-1:0] raddr,
    output reg                 rempty
);

    wire [ADDR_WIDTH:0] rbin_next, rgray_next;
    wire empty_next;

    assign rbin_next = rbin + (rinc & ~rempty);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;
    assign raddr = rbin[ADDR_WIDTH-1:0];

    // EMPTY: Gray read pointer equals synchronised Gray write pointer
    assign empty_next = (rgray_next == wgray_sync);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= 0;
            rgray  <= 0;
            rempty <= 1'b1;
        end else begin
            rbin   <= rbin_next;
            rgray  <= rgray_next;
            rempty <= empty_next;   // registered – pessimistic removal
        end
    end
endmodule