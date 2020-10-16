module can_clk
#(
   parameter FREQ_I = 50_000_000,
   parameter FREQ_O = 1_000_000,
   
   parameter END_COUNT = FREQ_I/(FREQ_O*2) - 1
)( 
   input rst_i,
   input clk_i,
   input sync_i,
   
   output can_clk_o
);


reg baud_clk_o_reg = 1'b0;
reg [9:0] count = 10'd0;

reg can_clk_o_reg;
assign can_clk_o = can_clk_o_reg;

always @( posedge clk_i ) begin
   if ( rst_i == 1 ) begin
      can_clk_o_reg     <= 1'b0;
      count             <= 10'd0;
   end
   else if ( sync_i ) begin
      count             <= 10'd0;
      can_clk_o_reg     <= 1'b1;
   end
   else if ( count == END_COUNT ) begin
      count             <= 10'd0;
      can_clk_o_reg     <= ~can_clk_o_reg;
   end else begin
      count             <= count + 10'd1;
   end
end

endmodule	