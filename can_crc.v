module can_crc
(	
	input 				crc_clk_i,
	input 				rst_i,
	input			    en_i,
	input 				data_i,
	input				crc_rst_i,
	output reg [14:0]	crc_reg_o
	
);

wire 	    crc_next;
wire [14:0] crc_tmp;
assign crc_next = data_i ^ crc_reg_o[14];
assign crc_tmp  = {crc_reg_o[13:0], 1'b0};

always @( posedge crc_clk_i or negedge rst_i or posedge crc_rst_i ) begin
	if ( rst_i == 1'b0 || crc_rst_i == 1'b1 ) begin
		crc_reg_o <= 15'h0;
	end else begin 
        if ( en_i ) begin	
            if ( crc_next ) begin 
                crc_reg_o <= crc_tmp ^ 15'h4599;
            end else begin
                crc_reg_o <= crc_tmp;
            end				
        end 
    end
end

endmodule