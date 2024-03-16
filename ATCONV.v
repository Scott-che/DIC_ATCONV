`timescale 1ns/10ps
module  ATCONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	
			
	output reg	[11:0]	iaddr,
	input signed [12:0]	idata,
	
	output	reg 	cwr,
	output  reg	[11:0]	caddr_wr,
	output reg 	[12:0] 	cdata_wr,
	
	output	reg 	crd,
	output reg	[11:0] 	caddr_rd,
	input 	[12:0] 	cdata_rd,
	
	output reg 	csel
	);

//=================================================
//            write your design below
//=================================================

localparam idle = 2'd0;
localparam atconv = 2'd1;
localparam  write_data= 2'd2;
localparam  finish = 2'd3 ;

parameter  signed k1 = 13'h1FFF;
parameter  signed k2 = 13'h1FFE;
parameter  signed k3 = 13'h1FFF;
parameter  signed k4 = 13'h1FFC;
parameter  signed k6 = 13'h1FFC;
parameter  signed k7 = 13'h1FFF;
parameter  signed k8 = 13'h1FFE;
parameter  signed k9 = 13'h1FFF;
parameter  signed bias = 13'h1FF4;

reg [2:0] state, nextstate;
reg [3:0] count;
reg [11:0] write_addr, layer1_addr;
reg signed [19:0] temp ,tmp;
reg signed [12:0] previous_max, max_pooling;
reg [6:0] X, Y, ori_X, ori_Y, new_X, new_Y;
reg [1:0] small_iteration;
reg [2:0] write_count;
reg [5:0] big_iteration;

wire [11:0] addr;
mapping map(addr, X, Y);

always @(*) begin
	iaddr = addr;
end

always @(*) begin  //計算conv
	case (count)
		4'd1: begin          //中心點
			tmp = idata;
		end
		4'd2: begin		    //左上	
			tmp = idata*k1;
		end
		4'd3:begin          //上中
			tmp = idata*k2;
		end
		4'd4: begin         //右上
			tmp = idata*k3;
		end
		4'd5: begin         //左
			tmp = idata*k4;
		end
		4'd6: begin         //右
			tmp = idata*k6;
		end
		4'd7: begin        //左下
			tmp = idata*k7;
		end
		4'd8: begin        //下中
			tmp = idata*k8;
		end
		4'd9: begin       //右下  
			tmp = idata*k9;
		end
		4'd10:begin
			tmp = temp + bias;
		end
		default:  begin
			tmp = 0;
		end
	endcase
end

always @(*) begin  //更新座標點，每一次conv迭代9次
	case (count)
		4'd1: begin          //中心點
			X = ori_X;
			Y = ori_Y;
		end
		4'd2: begin		    //左上	
			X = ori_X - 2;
			Y = ori_Y - 2;
		end
		4'd3:begin          //上中
			X = ori_X;
			Y = ori_Y - 2;
		end
		4'd4: begin         //右上
			X = ori_X + 2;
			Y = ori_Y - 2;
		end
		4'd5: begin         //左
			X = ori_X - 2;
			Y = ori_Y;
		end
		4'd6: begin         //右
			X = ori_X + 2;
			Y = ori_Y;
		end
		4'd7: begin        //左下
			X = ori_X - 2;
			Y = ori_Y + 2;
		end
		4'd8: begin        //下中
			X = ori_X;
			Y = ori_Y + 2;
		end
		4'd9: begin       //右下  
			X = ori_X + 2;
			Y = ori_Y + 2;
		end
		default:begin
			X = ori_X;
			Y = ori_Y;
		end
	endcase
end

always @(*) begin  //產生新的中心點
	case (small_iteration)
		2'd1:begin
			new_X = ori_X;
			new_Y = ori_Y + 1;
		end
		2'd2:begin
			new_X = ori_X + 1;
			new_Y = ori_Y;
		end
		2'd3:begin
			new_X = ori_X;
			new_Y = ori_Y - 1;
		end	 
		default:begin
			if(big_iteration < 32 && big_iteration > 0)begin
				new_X = ori_X + 1;
				new_Y = ori_Y;
			end
			else if(big_iteration == 32)begin
				new_X = 2;
				new_Y = ori_Y + 2;
			end
			else begin
				new_X = ori_X;
				new_Y = ori_Y;
			end
		end 
	endcase
end

always @(*) begin  //round up
	if(previous_max[3:0] != 0) begin
		max_pooling = {previous_max[12:4], 4'b0} + 13'b0000000010000;
	end
	else begin
		max_pooling = previous_max;
	end
end


always @(posedge clk) begin
	if(reset) begin
		state <= idle;
	end
	else begin
		state <= nextstate;
	end
end

always @(*) begin
	case (state)
		idle:begin
			if(ori_Y == 66) nextstate = finish;
			else nextstate = atconv;
		end
		atconv:begin
			if(count == 10) nextstate = write_data;
			else nextstate = atconv;
		end
		write_data:begin
			if(write_count == 3) nextstate = write_data;
			else nextstate = idle;
		end
		default:begin
			nextstate = finish;
		end 
	endcase
end

always @(posedge clk) begin
	if(reset) begin
		busy <= 0;
		ori_X <= 2;
		ori_Y <= 2;
		count <= 0;
		temp <= 0;
		small_iteration <= 0;
		big_iteration <= 0;
		write_count <= 0;
		layer1_addr <= 0;
		cwr <= 0;
		caddr_wr <= 0;
		cdata_wr <= 0;
		csel <= 0;
	end
	else if(ready) begin
		busy <= 1'b1;
	end
	else begin
		case (state)
			idle:begin
				cwr <= 0;
				ori_X <= new_X;
				ori_Y <= new_Y;
				if(big_iteration == 32) big_iteration <= 0;
				else big_iteration <= big_iteration;
			end
			atconv:begin
				count <= count + 1;
				if(count == 0)begin
					write_addr <= addr;
				end 
				else if(count == 1) temp <= tmp;
				else if(count > 1 && count < 10) temp <= temp + tmp[16:4];  //{tmp[16:8],tmp[7:4]}
				else if(count == 10)begin
					small_iteration <= small_iteration + 1;
					if(tmp[12] == 1) begin
						temp <= 0;
					end
					else begin
						temp <= tmp;
					end
				end
			end 
			write_data:begin
				write_count <= write_count + 1;
				cwr <= 1;
				count <= 0;
				if(write_count == 0) begin
					csel <= 0;
					caddr_wr <= write_addr;
					cdata_wr <= temp[12:0];
					previous_max <= temp[12:0];
				end
				else if(write_count > 0 && write_count < 4)begin
					csel <= 0;
					caddr_wr <= write_addr;
					cdata_wr <= temp;

					if(temp[12:0] > previous_max) begin
						previous_max <= temp[12:0];
					end
					else begin
						previous_max <= previous_max;
					end
				end
				else if(write_count == 4)begin   //write data to layer1 (after max-pooling)
					csel <= 1;
					caddr_wr <= layer1_addr;
					layer1_addr <= layer1_addr + 1;
					write_count <= 0;
					big_iteration <= big_iteration + 1;
					cdata_wr <= max_pooling;
				end
			end
			finish:begin
				busy <= 0;
			end 
		endcase
	end
end

endmodule

module mapping (result, x, y);

input [6:0] x;
input [6:0] y;
output reg [11:0] result;

reg [1:0] sel1, sel2;

always @(*) begin
	if(x < 3) begin
		sel1 = 2'b0;
	end
	else if((3 <= x) && (x < 65)) begin
		sel1 = 2'b01;
	end
	else begin
		sel1 = 2'b10; 
	end
end

always @(*) begin
	if(y < 3) begin
		sel2 = 2'b0;
	end
	else if((3 <= y) && (y < 65)) begin
		sel2 = 2'b01;
	end
	else begin
		sel2 = 2'b10; 
	end
end

always @(*) begin
	case ({sel1, sel2})
		4'b0000: begin
			result = 0;
		end
		4'b0001: begin
			result = 64*(y-2);
		end
		4'b0010: begin
			result = 4032;
		end
		4'b0100: begin
			result = x-2;
		end
		4'b0101: begin
			result = x-2+64*(y-2);
		end
		4'b0110: begin
			result = x-2+4032;
		end
		4'b1000: begin
			result = 63;
		end
		4'b1001: begin
			result = 63+64*(y-2);
		end
		default: begin
			result = 4095;
		end
	endcase
end

endmodule