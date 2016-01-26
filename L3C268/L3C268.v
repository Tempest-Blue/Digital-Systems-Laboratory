module L3C268( // where yyy=your CID. For example, L3C079 if your CID=079 
 input [9:0] sw, // ten up-down switches, SW9 - SW0 
 input [3:0] key, // four pushbutton switches, KEY3 - KEY0 
 input clock, // 24MHz clock source on Altera DE1 board 
 output [9:0] ledr, // ten Red LEDs, LEDR9 - LEDR0 
 output [7:0] ledg, // eight Green LEDs, LEDG8 - LEDG0 
 output reg [6:0] hex0, hex1, hex2, hex3 // four 7-segment, HEX3 - HEX0 
);
// State controller
reg[6:0] deposit = 0;
reg[6:0] change = 0;
reg[1:0] state = 0;
reg[1:0] errorCase = 0;
always @ (*)
begin
	if (state == 0)
		begin hx3(0); hx2(2); hx1(6); hx0(8); end // CID/Initial State
	if (state == 1)
		begin hx3(0); hx2(0); hx1(0); hx0(0); end // Zero State
	else if (~sw[9] && state == 2)
		begin
			if (errorCase) // Error State
				begin hx3(14); hx2(19); hx1(19); hx0(18); end
			else // Normal Operation
				begin hx3(deposit/10); hx2(deposit%10); hx1(change/10); hx0(change%10); end
		end
	else if (sw[9]) // Report State
		begin hx3(18); hx2(18); hx1(18); hx0(totalDispensed); end
end

// Key Operations
reg[1:0] consecutiveCredit = 0;
reg[1:0] consecutiveDollar = 0;
reg[1:0] creditInput = 0;
reg[1:0] reset = 0;
reg[6:0] totalDispensed = 0;
assign switch = sw[0] | sw[1] | sw[2] | sw[3] | sw[4] | sw[8];
always @ (negedge key[1])
begin
	if (state == 1 && errorCase)
		begin state = 2; errorCase = 0; deposit = 0; change = 0; consecutiveDollar = 0; consecutiveCredit = 0; end
	if (state < 2)
		begin state = state + 1; end
	else if (errorCase)
		begin state = 1; end
	if (state == 2 & switch)
		begin
			if (((sw[0] & (sw[1] | sw[2] | sw[3] | sw[4] | sw[8])) |
				 (sw[1] & (sw[0] | sw[2] | sw[3] | sw[4] | sw[8])) |
				 (sw[2] & (sw[0] | sw[1] | sw[3] | sw[4] | sw[8])) |
				 (sw[3] & (sw[0] | sw[1] | sw[2] | sw[4] | sw[8])) |
				 (sw[4] & (sw[0] | sw[1] | sw[2] | sw[3] | sw[8])) |
				 (sw[8] & (sw[0] | sw[1] | sw[2] | sw[3] | sw[4]))))	// More than one input error
				begin errorCase = 1; end
			else
				begin
					if (reset == 1)
						begin
							if (sw[4] & deposit == 35 & change == 0)	// Credit card error when HEX[3:0] == 3500
								begin errorCase = 1; end
							else
								begin
									change = 0;
									deposit = 0;
									reset = 0;
								end
						end
					if (sw[0])	// NICKEL
						begin 
							deposit = deposit + 5;
							consecutiveDollar = 0;
							consecutiveCredit = 0;
						end
					else if (sw[1])	// DIME
						begin 
							deposit = deposit + 10;
							consecutiveDollar = 0;
							consecutiveCredit = 0;
						end
					else if (sw[2])	// Quarter
						begin 
							deposit = deposit + 25;
							consecutiveDollar = 0;
							consecutiveCredit = 0;
						end
					else if (sw[3]) // Dollar
						begin
							deposit  = deposit + 100;
							consecutiveDollar = consecutiveDollar + 1;	
							if (consecutiveDollar == 2)	// Consecutive dollars error
								begin errorCase = 1; end
							consecutiveCredit = 0;
						end
					else if (sw[4]) // Credit Card
						begin 
							deposit = deposit + 35;
							consecutiveCredit = consecutiveCredit + 1;
							if (consecutiveCredit == 2)	// Consecutive credit card error
								begin errorCase = 1; end
							consecutiveDollar = 0;
						end
					else if (sw[8])	// Reset. Does not clear # dispensed.
						begin
							deposit = 0;
							change = 0;
							consecutiveDollar = 0;
							consecutiveCredit = 0;
						end
					if (deposit >= 35)
						begin
							if (reset == 0)
								begin
									if (errorCase != 1)
									begin
									change = change + (deposit - 35);
									deposit = 35;
									end
									if (totalDispensed == 15)
										begin totalDispensed = 0; end
									else if (errorCase != 1)
										begin totalDispensed = totalDispensed + 1; end
									reset = 1;
								end
						end
				end
		end
end


// Light Controller
reg[23:0] clockIndex;
reg [7:0] ledGreen;
reg [6:0] count;
assign ledg[7:0] = ledGreen;
always @(posedge clock)
begin
	if (deposit >= 35) // Flash at 50% duty for .5 second cycles
		begin
			clockIndex = clockIndex + 1;
			if (clockIndex == 6000000)
				begin
					clockIndex = 0;
					count = count + 1;
					if (count == 1)
						ledGreen = 8'b11111111;
					if (count == 2)
						begin ledGreen = 8'b00000000; count = 0; end
					if (state == 1)
						begin ledGreen = 8'b00000000; count = 0; end
				end
		end
	else
		begin
			ledGreen = 8'b00000000;
			count = 0;
			clockIndex = 0;
		end
end

// Controls HEX0 Display
task hx0;
input  [6:0] num;
begin
	case(num)
		0:  hex0 =  7'b1000000;  //0
		1:  hex0 =  7'b1111001;  //1
		2:  hex0 =  7'b0100100;  //2
		3:  hex0 =  7'b0110000;  //3
		4:  hex0 =  7'b0011001;  //4
		5:  hex0 =  7'b0010010;  //5
		6:  hex0 =  7'b0000010;  //6
		7:  hex0 =  7'b1111000;  //7
		8:  hex0 =  7'b0000000;  //8
		9:  hex0 =  7'b0011000;  //9
		10: hex0 =  7'b0001000;  //A
		11: hex0 =  7'b0000011;  //b
		12: hex0 =  7'b1000110;  //C
		13: hex0 =  7'b0100001;  //d
		14: hex0 =  7'b0000110;  //E
		15: hex0 =  7'b0001110;  //F
		16: hex0 =  7'b0001001;  //H
		17: hex0 =  7'b1000111;  //L
		18: hex0 =  7'b1111111;  //OFF
		19: hex0 =  7'b0101111;  //r
	endcase
end
endtask

task hx1;
input  [6:0] num;
begin
	case(num)
		0:  hex1 =  7'b1000000;  //0
		1:  hex1 =  7'b1111001;  //1
		2:  hex1 =  7'b0100100;  //2
		3:  hex1 =  7'b0110000;  //3
		4:  hex1 =  7'b0011001;  //4
		5:  hex1 =  7'b0010010;  //5
		6:  hex1 =  7'b0000010;  //6
		7:  hex1 =  7'b1111000;  //7
		8:  hex1 =  7'b0000000;  //8
		9:  hex1 =  7'b0011000;  //9
		10: hex1 =  7'b0001000;  //A
		11: hex1 =  7'b0000011;  //b
		12: hex1 =  7'b1000110;  //C
		13: hex1 =  7'b0100001;  //d
		14: hex1 =  7'b0000110;  //E
		15: hex1 =  7'b0001110;  //F
		16: hex1 =  7'b0001001;  //H
		17: hex1 =  7'b1000111;  //L
		18: hex1 =  7'b1111111;  //OFF
		19: hex1 =  7'b0101111;  //r
	endcase
end
endtask
	
task hx2;
input  [6:0] num;
begin
	case(num)
		0:  hex2 =  7'b1000000;  //0
		1:  hex2 =  7'b1111001;  //1
		2:  hex2 =  7'b0100100;  //2
		3:  hex2 =  7'b0110000;  //3
		4:  hex2 =  7'b0011001;  //4
		5:  hex2 =  7'b0010010;  //5
		6:  hex2 =  7'b0000010;  //6
		7:  hex2 =  7'b1111000;  //7
		8:  hex2 =  7'b0000000;  //8
		9:  hex2 =  7'b0011000;  //9
		10: hex2 =  7'b0001000;  //A
		11: hex2 =  7'b0000011;  //b
		12: hex2 =  7'b1000110;  //C
		13: hex2 =  7'b0100001;  //d
		14: hex2 =  7'b0000110;  //E
		15: hex2 =  7'b0001110;  //F
		16: hex2 =  7'b0001001;  //H
		17: hex2 =  7'b1000111;  //L
		18: hex2 =  7'b1111111;  //OFF
		19: hex2 =  7'b0101111;  //r
	endcase
end
endtask

task hx3;
input  [6:0] num;
begin
	case(num)
		0:  hex3 =  7'b1000000;  //0
		1:  hex3 =  7'b1111001;  //1
		2:  hex3 =  7'b0100100;  //2
		3:  hex3 =  7'b0110000;  //3
		4:  hex3 =  7'b0011001;  //4
		5:  hex3 =  7'b0010010;  //5
		6:  hex3 =  7'b0000010;  //6
		7:  hex3 =  7'b1111000;  //7
		8:  hex3 =  7'b0000000;  //8
		9:  hex3 =  7'b0011000;  //9
		10: hex3 =  7'b0001000;  //A
		11: hex3 =  7'b0000011;  //b
		12: hex3 =  7'b1000110;  //C
		13: hex3 =  7'b0100001;  //d
		14: hex3 =  7'b0000110;  //E
		15: hex3 =  7'b0001110;  //F
		16: hex3 =  7'b0001001;  //H
		17: hex3 =  7'b1000111;  //L
		18: hex3 =  7'b1111111;  //OFF
		19: hex3 =  7'b0101111;  //r
	endcase
end
endtask

endmodule
