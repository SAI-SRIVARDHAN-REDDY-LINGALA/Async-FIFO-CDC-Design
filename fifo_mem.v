// fifo_mem.v
module fifo_mem #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) (
    input  wire                    wclk,
    input  wire                    w_en,
    input  wire [ADDR_WIDTH-1:0]   waddr,
    input  wire [DATA_WIDTH-1:0]   wdata,
    input  wire [ADDR_WIDTH-1:0]   raddr,
    output wire [DATA_WIDTH-1:0]   rdata
);
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always @(posedge wclk) begin
        if (w_en)
            mem[waddr] <= wdata;
    end

    assign rdata = mem[raddr];
endmodule