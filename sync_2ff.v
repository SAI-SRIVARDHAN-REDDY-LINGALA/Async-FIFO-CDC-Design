// sync_2ff.v
module sync_2ff #(
    parameter WIDTH = 5
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] async_in,
    output wire [WIDTH-1:0] sync_out
);
    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] sync_ff1;  // ✅ attribute on the actual first flop
    reg [WIDTH-1:0] sync_ff2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= 0;
            sync_ff2 <= 0;
        end else begin
            sync_ff1 <= async_in;
            sync_ff2 <= sync_ff1;
        end
    end

    assign sync_out = sync_ff2;
endmodule