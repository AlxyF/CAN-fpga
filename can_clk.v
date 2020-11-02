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

reg [11:0] count;
reg can_clk_o_reg;

assign can_clk_o = can_clk_o_reg;

always @( posedge clk_i or negedge rst_i ) begin
   if ( rst_i == 1'b0 ) begin
      can_clk_o_reg     <= 1'b1;
      count             <= 12'd0;
   end else begin
       if ( sync_i ) begin
          count             <= 12'd0;
          can_clk_o_reg     <= 1'b1;
       end else if ( count == END_COUNT ) begin
          count             <= 12'd0;
          can_clk_o_reg     <= ~can_clk_o_reg;
       end else begin
          count             <= count + 1'b1;
       end
    end
end

endmodule	