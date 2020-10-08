module baud_rate
#(
	parameter FREQ_I = 50_000_000,
	parameter FREQ_O = 50_000,
	
	parameter END_COUNT = FREQ_I/(FREQ_O*2) - 1
)(	
	input rst_i,
	input clk_i,
	
	output baud_clk_o
);


reg baud_clk_o_reg = 1'b0;
reg [9:0] count = 10'd0;

assign baud_clk_o = baud_clk_o_reg;

always @(posedge clk_i) begin
	if (rst_i == 1) begin
		count 		<= 10'd0;
	end
	else if (count == END_COUNT) begin
		count 		<= 10'd0;
		baud_clk_o_reg 	<= ~baud_clk_o_reg;
 	end else begin
		count			<= count + 10'd1;
	end
end

endmodule	