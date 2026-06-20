// async_fifo.v
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4          // FIFO depth = 2^ADDR_WIDTH
) (
    input  wire                     wclk,
    input  wire                     wrst_n,
    input  wire                     winc,
    input  wire [DATA_WIDTH-1:0]    wdata,
    output wire                     wfull,

    input  wire                     rclk,
    input  wire                     rrst_n,
    input  wire                     rinc,
    output wire [DATA_WIDTH-1:0]    rdata,
    output wire                     rempty
);

    wire [ADDR_WIDTH:0]   wbin, rbin;
    wire [ADDR_WIDTH:0]   wgray, rgray;
    wire [ADDR_WIDTH:0]   wgray_sync, rgray_sync;
    wire [ADDR_WIDTH-1:0] waddr, raddr;

    // Memory
    fifo_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_mem (
        .wclk (wclk),
        .w_en (winc & ~wfull),
        .waddr(waddr),
        .wdata(wdata),
        .raddr(raddr),
        .rdata(rdata)
    );

    // Synchronizers
    sync_2ff #(
        .WIDTH(ADDR_WIDTH+1)
    ) u_sync_rptr (
        .clk    (wclk),
        .rst_n  (wrst_n),
        .async_in(rgray),
        .sync_out(rgray_sync)
    );

    sync_2ff #(
        .WIDTH(ADDR_WIDTH+1)
    ) u_sync_wptr (
        .clk    (rclk),
        .rst_n  (rrst_n),
        .async_in(wgray),
        .sync_out(wgray_sync)
    );

    // Write pointer & full
    write_ptr_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_wptr (
        .wclk       (wclk),
        .wrst_n     (wrst_n),
        .winc       (winc),
        .rgray_sync (rgray_sync),
        .wbin       (wbin),
        .wgray      (wgray),
        .waddr      (waddr),
        .wfull      (wfull)
    );

    // Read pointer & empty
    read_ptr_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_rptr (
        .rclk       (rclk),
        .rrst_n     (rrst_n),
        .rinc       (rinc),
        .wgray_sync (wgray_sync),
        .rbin       (rbin),
        .rgray      (rgray),
        .raddr      (raddr),
        .rempty     (rempty)
    );

endmodule