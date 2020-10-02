module can_top
(	
	// message length 1(SOF)+11(Arb1)+2(SRR,IDE)+1(RTR)+1(r1)+1(r0)+4(Control)+15(CRC Field)+1(CRC Delimeter)+2(Ack)+7(EoF)+3(Idle)
	
	input  rst_i,
	input  clk_i,
	
	input  rx_i,
	output rx_busy,
	
	output tx_o,
	output tx_busy,
	
	input command_or_data,
	
	// - output CAN frame LLC/DLC data
	
	// -- Arbitration field
	input type, 							// command 0, data 1
	input [5:0] address_sender,		// 
	input [5:0] address_recipient,	// 
	input [1:0] sign, 				   // kvitirovanie
	//input 		type,
	// -- Control
	input [3:0] data_l_i,
	
	// -- Data
	input [63:0] data_b_i,
	
	output [7:0] data_o,
	
	// test
	output test_clk_can,
	output [2:0] test_can_state,
	output [3:0] test_can_tx_state,
	output [7:0] bit_count,
	output [3:0] test_bit_pol_count,
	output reg bit_stuffed,
	output test_last_bit
);
// <test>
assign test_clk_can   = clk_can;
assign test_can_tx_state =  TX_STATE;
assign test_can_state    = CAN_STATE;
assign bit_count   = bit_count_reg;
assign test_bit_pol_count = bit_pol_count;

assign test_last_bit = last_bit;



// </test>

reg tx_o_reg;
assign tx_o = tx_o_reg;


wire clk_can;



reg [63:0] data_to_send;

// constant regs
localparam [5:0] local_address  = 6'b000000;//6'h2A;		
localparam [5:0] remote_address = 6'b000000;

localparam CAN_IDLE = 0;
localparam CAN_RX   = 1;
localparam CAN_TX   = 2;

reg[3:0] CAN_STATE;	
		
always @( posedge clk_i or posedge rst_i ) begin
	if ( rst_i ) begin
		CAN_STATE <= CAN_IDLE;
	end else begin
		case ( CAN_STATE )
		CAN_IDLE:	begin
							CAN_STATE <= CAN_TX;
						end
		CAN_RX:			begin
						end
		CAN_TX:		begin
							
						end
		endcase
	end
end

//bit stuffing aux regs 
reg [7:0] bit_count_reg;					
reg [2:0] bit_pol_count;
reg 		 last_bit; 

reg [2:0] count;

reg [14:0] crc_reg = 15'd0;

wire crc_next;
assign crc_next = tx_o_reg ^ crc_reg[14];

wire [14:0] crc_tmp;
assign crc_tmp  = {crc_reg[13:0], 1'b0};

reg [3:0] crc_reg_count;
					
localparam TX_IDLE          = 0;
localparam TX_START         = 1;
localparam TX_MESSAGE_TYPE  = 2;
localparam TX_ADDRESS_L     = 3;
localparam TX_ADDRESS_R     = 4;
localparam TX_SRR    		 = 5;
localparam TX_IDE  		    = 6;
localparam TX_HANDSHAKING_P = 7;
localparam TX_RESERVED		 = 8;
localparam TX_EXPAND_COUNT  = 9;
localparam TX_CMD_DATA_SIGN = 10;
localparam TX_DLC				 = 11;
localparam TX_DATA			 = 12;

localparam TX_CRC 			= 14;

localparam TX_BIT_STUFF    = 15; 

reg[3:0] TX_STATE;
reg[3:0] NEXT_TX_STATE;
					
reg bit_stuff_bit;

					
always @( posedge clk_can or posedge rst_i ) begin
	if ( rst_i ) begin
		TX_STATE             <= TX_IDLE;
		NEXT_TX_STATE 			<= TX_IDLE;
		bit_count_reg 			<= 8'd0;
		last_bit					<= 1'b0;
	   bit_pol_count 			<= 3'd1;
		count 					<= 3'd0;
	end else begin
		if ( CAN_STATE == CAN_TX ) begin
			if ( TX_STATE != TX_IDLE  ) begin
				last_bit 		<= tx_o_reg;
				bit_count_reg  <= bit_count_reg + 1'b1;		
			end
			case ( TX_STATE )
			TX_IDLE: 			begin	
										count 			<= 3'd0;
										bit_count_reg 	<= 8'd0;
										TX_STATE			<= TX_START;								
									end
			// - MAC-level
			
			// -- SOF
			// 1 bit do not count into message
			TX_START:			begin											
										TX_STATE 	  	<= TX_MESSAGE_TYPE;
										NEXT_TX_STATE 	<= TX_MESSAGE_TYPE;								
									end					
			// -- every 5 consequent same polarity, but not for CRC delimiter, ACK field and end of frame
			// 1 bit
			TX_BIT_STUFF: 		begin		
										TX_STATE 		<= NEXT_TX_STATE;	
									end				
			//	-- IDE and SRR are placed between 18 and 17 bit of 29 bit arbitration field
			// 1 bit
			TX_SRR:				begin
										TX_STATE 		<= TX_IDE;
										NEXT_TX_STATE 	<= TX_IDE;
									end
			// 1 bit
			TX_IDE:				begin
										TX_STATE 		<= TX_ADDRESS_R;
										NEXT_TX_STATE 	<= TX_ADDRESS_R;
									end
			// -- exclude start of the frame bit
			// 15 bit
			TX_CRC:				begin
										if ( count == 7'd14 ) begin
											count 			<= 7'd0;
											TX_STATE 		<= TX_IDLE;
										end else begin
											count 			<= count + 1'b1;
										end		
									end
			// 1 bit
			TX_CRC_DELIM:		begin
										TX_STATE 		<= TX_ADDRESS_R;
										NEXT_TX_STATE 	<= TX_ADDRESS_R;	
									end
								
			// - LLC-level
			
			// -- Identificator
			
			// --- C/D
			// 1 bit
			TX_MESSAGE_TYPE:	begin
										TX_STATE 	  			<= TX_ADDRESS_L;
										NEXT_TX_STATE 			<= TX_ADDRESS_L;	
									end
			// --- Address local
			// 6 bit
			TX_ADDRESS_L:  	begin
										if ( count == 7'd5 ) begin
											count 				<= 7'd0;							
											TX_STATE 			<= TX_ADDRESS_R;
											NEXT_TX_STATE 		<= TX_ADDRESS_R;	
										end else begin													
											count 				<= count + 1'b1;	
										end
									end
			// --- Address remote
			// 6 bit						
			TX_ADDRESS_R:		begin
										if ( count == 7'd5 ) begin
											count 				<= 7'd0;	
											TX_STATE 			<= TX_HANDSHAKING_P;
											NEXT_TX_STATE 		<= TX_CRC;	
										end else begin					
											if ( count == 7'd3 ) begin
												count 			<= count + 1'b1;
												TX_STATE 		<= TX_SRR;
												NEXT_TX_STATE 	<= TX_SRR;
											end else begin																			
												count 			<= count + 1'b1;
											end	
										end
									end
			// --- Atribute
			
			// DataFrame: pointer?, CommandFrame: handshaking
			// 2 bit
			TX_HANDSHAKING_P:	begin
										if ( count == 7'd1 ) begin
											count					<= 7'd0;
											TX_STATE 			<= TX_RESERVED;
											NEXT_TX_STATE 		<= TX_RESERVED;	
										end else begin
											count 				<= count + 1'b1;
										end
									end
			// DataFrame: reserved 2'b00, CommandFrame: 2'b10
			// 2 bit
			TX_RESERVED:		begin
										if ( count == 7'd1 ) begin
											count					<= 7'd0;
											TX_STATE 			<= TX_EXPAND_COUNT;
											NEXT_TX_STATE 		<= TX_EXPAND_COUNT;	
										end else begin
											count 				<= count + 1'b1;
										end										
									end
			// DataFrame: frame count, CommandFrame: expand command field
			// 4 bit		
			TX_EXPAND_COUNT:	begin
										if ( count == 7'd3 ) begin
											count					<= 7'd0;
											TX_STATE 			<= TX_CMD_DATA_SIGN;
											NEXT_TX_STATE 		<= TX_CMD_DATA_SIGN;	
										end else begin
											count 				<= count + 1'b1;
										end
									end
			// --- Data/Command sign
			
			// DataFrame: type of data, CommandFrame: type of command
			// 8 bit
			TX_CMD_DATA_SIGN: begin
										if ( count == 7'd7 ) begin
											count					<= 7'd0;
											TX_STATE 			<= TX_DLC;
											NEXT_TX_STATE 		<= TX_DLC;	
										end else begin
											count 				<= count + 1'b1;
										end										
									end
			// -- DLC
			// 4 bit
			TX_DLC:				begin
										if ( count == 7'd3 ) begin
											count					<= 7'd0;
											TX_STATE 			<= TX_CRC;
											NEXT_TX_STATE 		<= TX_CRC;	
										end else begin
											count 				<= count + 1'b1;
										end											
									end
			
			// -- Data
			// 0 or 64 bit
			TX_DATA:				begin
										if ( count == 7'd63 ) begin
											count					<= 7'd0;
											TX_STATE 			<= TX_CRC;
											NEXT_TX_STATE 		<= TX_CRC;	
										end else begin
											count 				<= count + 1'b1;
										end		
									end
									
			endcase
			
			// <CRC>
			if ( TX_STATE != TX_IDLE &
				   TX_STATE != TX_START &
					 TX_STATE != TX_BIT_STUFF &
					  TX_STATE != TX_CRC ) begin	
				if ( crc_next ) begin 
					crc_reg <= crc_tmp ^ 15'h4599;
				end else begin
					crc_reg <= crc_tmp;
				end				
			end
			// </CRC>
			
			// <bit stuff check>
			if ( TX_STATE != TX_IDLE ) begin // add other states
				if ( tx_o_reg == last_bit ) begin	
					bit_pol_count 			<= bit_pol_count + 1'b1;					
						if ( bit_pol_count == 3'd5 ) begin
							if ( tx_o_reg == 1'b0 ) begin
								bit_stuff_bit <= 1'b1;
							end else begin
								bit_stuff_bit <= 1'b0;
							end							
							bit_pol_count 	<= 3'd1;
							TX_STATE 	  	<= TX_BIT_STUFF;
						end				
				end else begin						
					bit_pol_count 	<= 3'd2;								
				end
			end
			// </bit stuff check>
			
		end
	end
end


always @( posedge clk_i ) begin
		
	
	bit_stuffed <= 1'b0;
	if ( TX_STATE == TX_START ) begin
		tx_o_reg      <= 1'b0;
		//bit_pol_count <= 1'd1;
	end else begin
	
	if ( TX_STATE == TX_BIT_STUFF ) begin
			tx_o_reg 	<= bit_stuff_bit;
			bit_stuffed <= 1'b1; // for testing			
	end else begin 
	
	if ( TX_STATE == TX_MESSAGE_TYPE ) begin
		tx_o_reg			<= type;
	end else begin
	
	if ( TX_STATE == TX_SRR ) begin
		tx_o_reg		  	<= 1'b1;
	end else begin 
	
	if ( TX_STATE == TX_IDE ) begin
		tx_o_reg		  	<= 1'b1;
	end else begin 

	if ( TX_STATE == TX_ADDRESS_L ) begin
		tx_o_reg					<= local_address[3'd5 - count];	
	end else begin
	
	if ( TX_STATE == TX_ADDRESS_R ) begin
		tx_o_reg					<= remote_address[3'd5 - count];			
	end else begin
	
	if ( TX_STATE == TX_CRC ) begin
		tx_o_reg <= crc_reg[4'd14 - crc_reg_count];
	end
	
	end
	end 
	end
	end
	end
	end
	end
	
end

baud_rate baud_rate_gen
(
	.rst_i 		(rst_i),
	.clk_i 		(clk_i),
	.baud_clk_o (clk_can)
);
	


endmodule
