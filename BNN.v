module BNN
(
	//Control Signals
	input wire		run,		//Start processing
	output reg		busy,
	input wire 		reset,		//Active low Reset
	input wire		clk,		//Clock
	
	//Input and output SRAM interface
	output reg [11:0]	dut_sram_write_address,
	output reg [15:0]	dut_sram_write_data,
	output reg 			wr_enable,
	output reg [11:0]	dut_sram_read_address,	//SRAM read address
	input wire [15:0]	sram_dut_read_data,	//SRAM read data
	
	//Weight SRAM interface
	output reg [11:0]	dut_wmem_read_address,
	input wire [15:0]	wmem_dut_read_data
);

	//Parameters
	localparam s0  = 3'b000;
	localparam s1  = 3'b001;
	localparam s2  = 3'b010;
	localparam s3  = 3'b011;
	localparam s4  = 3'b100;
	localparam s5  = 3'b101;
	localparam s6  = 3'b110;
	localparam s7  = 3'b111;
	localparam s8  = 4'b1000;
	localparam s9  = 4'b1001;
	localparam s10 = 4'b1010;
	localparam s11 = 4'b1011;
	localparam s12 = 4'b1100;
	localparam s13 = 4'b1101;
	
	//Reg declaration
	reg [15:0]		SizeCount;	//Count of data to be read from SRAM 
	reg [15:0]		SizeCount_check;  //to account for 3 different input sizes
	reg [15:0]		State8SizeCountCheck;
	reg [15:0]		Ain;		//Value of A
	reg [15:0]		Win;
	//reg [3:0]		Bin;		//Value of B
	reg [15:0]		Accumulator;	//Accumulator
	reg [3:0]		current_state;	//FSM current state
	reg [3:0]		next_state;	//FSM next state
	reg [1:0]		size_count_sel;	//Select line for mux that manipulates size count register for input
	reg [1:0]		wmem_read_addr_sel;//Select line for mux that manipulates weight address register
	reg [1:0]		write_addr_sel; //Write address select
	reg [1:0]		read_addr_sel;	//Select line for mux that manipulates read address register
	reg [1:0]		Accumulate_sel;	//Select line for mux that manipulates Accumulator register
	reg 			Aenable;	//Enable for Input register
	reg				WEnable; //Enable for weight register
	//Wire declaration
	wire [15:0]		AmulB;		//Can be max 8 bits, both Ain and Bin 4 bits
	reg [15:0]		RowN;
	reg [15:0]		RowN1;
	reg [15:0]		RowN2;
	reg [2:0]		result; //result after XNOR and sum
	reg 			res_temp;
	reg [15:0]		Result_RowN; //Result of individual row	
	reg 			carry;
	reg [15:0]		Output; //stores the output after convolution
	integer i;
	//Control Path
		
	//FSM
	always @(posedge clk or negedge reset) begin
		if (!reset)begin
			current_state <= 4'b0;
			busy = 0;
		end
		else
			current_state <= next_state;
	end
	
	always @(*) begin
		casex (current_state)
			s0 : begin
				size_count_sel 	= 2'b10;
				read_addr_sel 	= 2'b10;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b0;
				WEnable = 1'b0;
				busy = 0;
				//Accumulate_sel 	= 2'b10;
				if (run == 1'b1)
					next_state = s1;
				else
					next_state = s0;
			end
			s1 : begin
				size_count_sel 	= 2'b10;
				read_addr_sel 	= 2'b00;
				wmem_read_addr_sel = 2'b00;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b0;
				WEnable = 1'b0;
				busy = 1;
				//Accumulate_sel 	= 2'b10;
				next_state 	= s2;
			end
			s2 : begin
				size_count_sel 	= 2'b10;
				read_addr_sel 	= 2'b01;
				wmem_read_addr_sel = 2'b01;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b0;
				WEnable = 1'b0;
				busy = 1;
				
				if(sram_dut_read_data == 8'hff)
					next_state = s0;
				else
					next_state 	= s3;
			end
			s3 : begin
				size_count_sel 	= 2'b00;
				read_addr_sel 	= 2'b01;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b0;
				WEnable = 1'b0;
				busy = 1;
				//Accumulate_sel 	= 2'b10;
				next_state = s4;
			end
			s4 : begin
				size_count_sel 	= 2'b00;
				read_addr_sel 	= 2'b01;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b0;
				WEnable = 1'b0;
				busy = 1;
				//Accumulate_sel 	= 2'b10;
				//if(SizeCount == (SizeCount_check - 16'b11))
				//	next_state = s8;
				//else
				next_state = s5;
			end
			s5 : begin
				size_count_sel 	= 2'b01;
				read_addr_sel 	= 2'b01;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b0;
				WEnable = 1'b1;
				busy = 1;
				if(SizeCount == (SizeCount_check - 16'b10))
					next_state = s8;
				//else if (SizeCount == 16'b10)
				//	next_state = s6;
				else
					next_state = s5;
			end
			s6 : begin
				size_count_sel 	= 2'b01;
				read_addr_sel 	= 2'b10;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b01;
				wr_enable	= 1'b1;
				WEnable = 1'b1;
				busy = 1;
				//Accumulate_sel 	= 2'b01;
				if (SizeCount == 16'b01)
					next_state = s7;
				else
					next_state = s6;
			end
			s7 : begin
				size_count_sel 	= 2'b10;
				read_addr_sel 	= 2'b10;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b01; 
				wr_enable	= 1'b1;
				WEnable = 1'b1;
				busy = 1;
				//if(SizeCount == 16'b0)
				next_state = s10;
				//Accumulate_sel 	= 2'b01;
				//else
				//	next_state 	= s2;
			end
			s8 : begin
				size_count_sel 	= 2'b01;
				read_addr_sel 	= 2'b01;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b00;
				wr_enable	= 1'b1;
				WEnable = 1'b1;
				busy = 1;
				//if (SizeCount == 16'b10)
				//	next_state = s6;
				//else
				next_state 	= s9;
			end
			s9 : begin
				size_count_sel 	= 2'b01;
				read_addr_sel 	= 2'b01;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b01;
				wr_enable	= 1'b1;
				WEnable = 1'b1;
				busy = 1;
				if (SizeCount == 16'b10)
					next_state = s6;
				else
					next_state 	= s9;
				
			end
			s10 : begin
				size_count_sel 	= 2'b10;
				read_addr_sel 	= 2'b01;
				wmem_read_addr_sel = 2'b01;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b1;
				WEnable = 1'b1;
				busy = 1;
				next_state = s11;
				
				if(sram_dut_read_data == 8'hff)
					next_state = s0;
				else
					next_state 	= s11;
				
				end
				
			s11 : begin
				size_count_sel 	= 2'b00;
				read_addr_sel 	= 2'b01;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b0;
				WEnable = 1'b0;
				busy = 1;
				//Accumulate_sel 	= 2'b10;
				next_state = s12;
				end
			s12 : begin
				size_count_sel 	= 2'b00;
				read_addr_sel 	= 2'b01;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b0;
				WEnable = 1'b0;
				busy = 1;
				next_state = s13;
				end
			s13 : begin
				size_count_sel 	= 2'b01;
				read_addr_sel 	= 2'b01;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b0;
				WEnable = 1'b1;
				busy = 1;
				if(SizeCount == (SizeCount_check - 16'b10))
					next_state = s9;
				//else if (SizeCount == 16'b10)
				//	next_state = s6;
				else
					next_state = s13;
				end
			
				//Accumulate_sel 	= 2'b10;
				//next_state 	= s0;
			default : begin
				size_count_sel 	= 2'b10;
				read_addr_sel 	= 2'b10;
				wmem_read_addr_sel = 2'b10;
				write_addr_sel = 2'b10;
				wr_enable	= 1'b0;
				WEnable = 1'b0;
				busy = 1;
				//Accumulate_sel 	= 2'b10;
				next_state 	= s0;
			end
		endcase 
	end
	
	//Data Path
	//Size count register
	always @(posedge clk) begin
			if (size_count_sel == 2'b0)
				begin
					SizeCount <= sram_dut_read_data;
					SizeCount_check <= sram_dut_read_data;
				end
			else if (size_count_sel == 2'b01)
			    SizeCount <= SizeCount - 16'b1;
			else if(size_count_sel == 2'b10)	 
				SizeCount <= SizeCount;
			
	end	
	
	
	always @(*) begin
		carry = 1'b0;
		result = 3'b0;
		Result_RowN = 16'b0;
		//if(SizeCount_check == 16'b10000) Compute regardless
		//	begin
				//Computing Row wise convolution
				for(i=0; i<14; i = i+1) begin
					{carry, result} = {2'b00,((RowN2[i]~^Win[0]))} + {2'b00,((RowN2[i+1]~^Win[1]))} + {2'b00,((RowN2[i+2]~^Win[2]))} +
								{2'b00,((RowN1[i]~^Win[3]))} + {2'b00,((RowN1[i+1]~^Win[4]))} + {2'b00,((RowN1[i+2]~^Win[5]))} +
									{2'b00,((RowN[i]~^Win[6]))} + {2'b00,((RowN[i+1]~^Win[7]))} + {2'b00,((RowN[i+2]~^Win[8]))};
					
					//$display("RowN2 :",RowN2);
					//$display("RowN2 :",RowN1);
					//$display("RowN2 :",RowN);
						
					//{carry, res_temp} = (RowN2[i]~^Win[0]) + (RowN2[i+1]~^Win[1]) + (RowN2[i+2]~^Win[2]);
					//result[0] = res_temp;
					//{carry,res_temp} = carry + 
					
					//$display("result :", result);
					if({carry,result} <= 3'b100)
						begin
							Result_RowN[i] = 0;	
						end
					else
						begin
							Result_RowN[i] = 1;
						end
				//end
					
			
	end
		
		if(SizeCount_check == 16'b1100) begin
			Result_RowN = {6'b0, Result_RowN[9:0]};
		end
		else if (SizeCount_check == 16'b1010) begin
			Result_RowN = {8'b0, Result_RowN[7:0]};
		end
	
	
	
	end
	
	//A and B register
	always @(posedge clk) begin
			if (WEnable == 1'b0) begin
				Ain <= 16'b0;
				Win <= 16'b0;
				RowN<= 16'b0;
				RowN1<= 16'b0;
				RowN2<= 16'b0;
				//Bin <= 4'b0;
			end
			else if (WEnable == 1'b1) begin
				Ain <= sram_dut_read_data[15:0];
				Win <= wmem_dut_read_data[15:0];
				//Bin <= read_data[7:4];
				RowN<= sram_dut_read_data[15:0];
				RowN1<=RowN;
				RowN2<=RowN1;
				
				//Value of output after computation
				//Output<=Result_RowN;
			end
	end
	
	
	//input Read address register
	always @(posedge clk) begin
			if (read_addr_sel == 2'b0)
				dut_sram_read_address <= 12'b0; //changing start in the input SRAM to index 1
			else if (read_addr_sel == 2'b01)
				dut_sram_read_address <= dut_sram_read_address + 12'b1;
			else if (read_addr_sel == 2'b10)
				dut_sram_read_address <= dut_sram_read_address;
	end
	
	//output address write register
	always @(posedge clk) begin
			if(write_addr_sel == 2'b0)
				begin
					dut_sram_write_address <= 12'b0;
					dut_sram_write_data <= Result_RowN;					
				end
			else if(write_addr_sel == 2'b01)
				begin
					dut_sram_write_address <= dut_sram_write_address + 12'b1;
					dut_sram_write_data <= Result_RowN;
				end
			else if(write_addr_sel == 2'b10)
				begin	
					dut_sram_write_address <= dut_sram_write_address;
					dut_sram_write_data <= dut_sram_write_data;
					
				end
	end
				
					
	//weight Read address register
	always @(posedge clk) begin
			if (wmem_read_addr_sel == 2'b0)
				dut_wmem_read_address <= 12'b1; //changing start in the input SRAM to index 1
			else if (wmem_read_addr_sel == 2'b01)
				dut_wmem_read_address <= 12'b1;
			else if (wmem_read_addr_sel == 2'b10)
				dut_wmem_read_address <= dut_wmem_read_address;
	end
endmodule