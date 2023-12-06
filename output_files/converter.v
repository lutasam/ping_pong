module converter(address, x, y);
	input [18:0] address;
	output reg [9:0] x, y;
	
	always @(address) begin
		x <= address / (10'd640);
		y <= address % (10'd640);
	end
endmodule