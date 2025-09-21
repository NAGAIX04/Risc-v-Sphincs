`timescale 1ns / 1ps

module RTL_crypto_hashblocks_sha256(
												input wire 			CLK,
                                    input	wire			RST,
                                    input	wire			start_in,
                                    input	wire	[511:0]	message_in,
                                    input	wire	[255:0]	digest_in,
                                    output	reg		[255:0]	digest_out,
                                    output	reg            	valid_out
);

    reg  [6:0] 		round_reg;
    reg				round_add;
        
    reg [511:0] 	message_reg;	
        
    wire [31:0] 	W0_wr, W1_wr, W2_wr, W3_wr, W4_wr, W5_wr, W6_wr, W7_wr, W8_wr, W9_wr, W10_wr, W11_wr, W12_wr, W13_wr, W14_wr, W15_wr, W16_wr;

    
    wire [31:0] 	a_wr, b_wr, c_wr, d_wr, e_wr, f_wr, g_wr, h_wr, a_new_wr, e_new_wr;

    reg [255:0] 	digest_reg;	
    reg [255:0] 	digest_init_reg;
    
 
   
    wire [31:0] 	sigma0_wr;
	wire [31:0] 	sigma1_wr;
	
	wire [31:0] 	SIGMA0_wr;
	wire [31:0] 	SIGMA1_wr;
	
	wire [31:0]  	Ch_wr;
	wire [31:0]  	Maj_wr;
	
    reg	 [31:0]		K_reg;

    // Controller
    always @ (posedge CLK)
    begin 
        if(RST == 1'b0) begin
            round_reg 			<= 7'b0;
            round_add			<= 1'b0;
        end
        else begin
            if(start_in) begin
                round_add			<= 1'b1;
                round_reg 			<= round_reg + 1'b1;
            end
            else if (round_reg == 7'd65) begin
                round_reg  		<= 7'b0;
                round_add		<= 1'b0;
            end
            else begin
                round_add			<= round_add;
                round_reg 			<= round_reg + round_add;
            end
        end
	end

    // Expander

	assign W0_wr  = (start_in) ? message_in[511:480] : message_reg[511:480];
	assign W1_wr  = (start_in) ? message_in[479:448] : message_reg[479:448];
	assign W2_wr  = (start_in) ? message_in[447:416] : message_reg[447:416];
	assign W3_wr  = (start_in) ? message_in[415:384] : message_reg[415:384];
	assign W4_wr  = (start_in) ? message_in[383:352] : message_reg[383:352];
	assign W5_wr  = (start_in) ? message_in[351:320] : message_reg[351:320];
	assign W6_wr  = (start_in) ? message_in[319:288] : message_reg[319:288];
	assign W7_wr  = (start_in) ? message_in[287:256] : message_reg[287:256];
	assign W8_wr  = (start_in) ? message_in[255:224] : message_reg[255:224];
	assign W9_wr  = (start_in) ? message_in[223:192] : message_reg[223:192];
	assign W10_wr = (start_in) ? message_in[191:160] : message_reg[191:160];
	assign W11_wr = (start_in) ? message_in[159:128] : message_reg[159:128];
	assign W12_wr = (start_in) ? message_in[127:96 ] : message_reg[127:96 ];
	assign W13_wr = (start_in) ? message_in[95:64  ] : message_reg[95:64  ];
	assign W14_wr = (start_in) ? message_in[63:32  ] : message_reg[63:32  ];
	assign W15_wr = (start_in) ? message_in[31:0   ] : message_reg[31:0   ];


//    RTL_EXPAND_32 RTL_EXPAND_32_0(.W0(), .W1(), .W2(), .W3(), .W4(), .W5(), .W6(), .W7(), .W8(), .W9(), .W10(), .W11(), .W12(), .W13(), .W14(), .W15(),
//   
/*                               .W0_out(), .W1_out(), .W2_out(), .W3_out(), .W4_out(), .W5_out(), .W6_out(), .W7_out(), .W8_out(), .W9_out(), .W10_out(), .W11_out(), .W12_out(), .W13_out(), .W14_out(), .W15_out());
    RTL_Msigma0_32 Msigma0_32_0(.x(W1_wr),.result(sigma0_out));
    RTL_Msigma1_32 Msigma1_32_0(.x(W14_wr),.result(sigma1_out));


    
    assign W16_wr = sigma0_out + W0_wr + sigma1_out + W9_wr;   
    */
    assign sigma0_wr = {W1_wr[6:0],W1_wr[31:7],W1_wr[6:0],W1_wr[31:7]}^{W1_wr[17:0],W1_wr[31:18],W1_wr[17:0],W1_wr[31:18]}^{3'b000,W1_wr[31:3],3'b000,W1_wr[31:3]};
	assign sigma1_wr = {W14_wr[16:0],W14_wr[31:17],W14_wr[16:0],W14_wr[31:17]}^{W14_wr[18:0],W14_wr[31:19],W14_wr[18:0],W14_wr[31:19]}^{10'b0000000000,W14_wr[31:10],10'b0000000000,W14_wr[31:10]};

	assign W16_wr = sigma0_wr + sigma1_wr + W0_wr + W9_wr; 
	
   always @(posedge CLK or negedge RST) 
	begin
		if(RST == 1'b0) begin
			message_reg 	<= 512'b0;
		end
		else begin
			message_reg <= {W1_wr, W2_wr, W3_wr, W4_wr, W5_wr, W6_wr, W7_wr, W8_wr, W9_wr, W10_wr, W11_wr, W12_wr, W13_wr, W14_wr, W15_wr, W16_wr};
		end
	end
    
    // F_32
    assign a_wr = (start_in) ? digest_in[255:224] : digest_reg[255:224];
	assign b_wr = (start_in) ? digest_in[223:192] : digest_reg[223:192];
	assign c_wr = (start_in) ? digest_in[191:160] : digest_reg[191:160];
	assign d_wr = (start_in) ? digest_in[159:128] : digest_reg[159:128];
	assign e_wr = (start_in) ? digest_in[127:96 ] : digest_reg[127:96 ];
	assign f_wr = (start_in) ? digest_in[95:64  ] : digest_reg[95:64  ];
	assign g_wr = (start_in) ? digest_in[63:32  ] : digest_reg[63:32  ];
	assign h_wr = (start_in) ? digest_in[31:0   ] : digest_reg[31:0   ];
	
	/*
    RTL_Sigma0_32 Sigma0_F32(.x(a_wr),.result(F_SIGMA0_out));
    RTL_Sigma1_32 Sigma1_F32(.x(e_wr),.result(F_SIGMA1_out));
    RTL_Ch Ch_F32(.x(e_wr),.y(f_wr),.z(g_wr),.result(Ch_out));
    RTL_Maj Maj_F32(.x(a_wr),.y(b_wr),.z(c_wr),.result(Maj_out));
    
    assign T1_wr = h_wr + F_SIGMA1_out + Ch_out + K_reg + W0_wr;
    assign T2_wr = F_SIGMA0_out + Maj_out;
    assign a_new_wr = T1_wr + T2_wr;
    assign e_new_wr = d_wr + T1_wr;
    */
    assign SIGMA1_wr 	= {e_wr[5:0],e_wr[31:6]} ^ {e_wr[10:0], e_wr[31:11]} ^ {e_wr[24:0], e_wr[31:25]};
	assign SIGMA0_wr 	= {a_wr[1:0], a_wr[31:2]} ^ {a_wr[12:0], a_wr[31:13]} ^ {a_wr[21:0], a_wr[31:22]};
	assign Ch_wr   	 	= (e_wr & f_wr) ^ ((~e_wr) & g_wr);
	assign Maj_wr	 	= (a_wr & b_wr) ^ (a_wr & c_wr) ^ (b_wr & c_wr);

	assign a_new_wr 		= SIGMA0_wr + Maj_wr + K_reg + W0_wr + h_wr + SIGMA1_wr + Ch_wr;
	assign e_new_wr 		= K_reg + W0_wr + h_wr + SIGMA1_wr + Ch_wr + d_wr;

    always @(posedge CLK or negedge RST)	
	begin
		if(RST == 1'b0) begin
			digest_reg			<= 256'h0;
			digest_init_reg	    <= 256'h0;
			digest_out			<= 256'h0;
			valid_out			<= 1'b0;
		end
		else begin
			digest_reg		<= {a_new_wr,a_wr,b_wr,c_wr,e_new_wr,e_wr,f_wr,g_wr};
			
			if(start_in) begin								
				digest_init_reg	    <= digest_in;
				digest_out			<= 256'h0;
				valid_out			<= 1'b0;
			end
			else if(round_reg == 7'd64) begin
			
				digest_out[255:224] <= digest_init_reg[255:224] + digest_reg[255:224];
				digest_out[223:192] <= digest_init_reg[223:192] + digest_reg[223:192];
				digest_out[191:160] <= digest_init_reg[191:160] + digest_reg[191:160];
				digest_out[159:128] <= digest_init_reg[159:128] + digest_reg[159:128];
				digest_out[127:96] 	<= digest_init_reg[127:96]  + digest_reg[127:96];
				digest_out[95:64] 	<= digest_init_reg[95:64]   + digest_reg[95:64];  
				digest_out[63:32]	<= digest_init_reg[63:32]   + digest_reg[63:32];  
				digest_out[31:0] 	<= digest_init_reg[31:0]    + digest_reg[31:0];   
				
				valid_out			<= 1'b1;
			end
			else begin				
				digest_init_reg	    <= digest_init_reg;				
				//digest_out			<= 256'h0;
				digest_out			<= digest_out;
				valid_out			<= 1'b0;
			end
		end
	end
    
       
    always @*
    begin
        case(round_reg)
            7'd00: K_reg <= 32'h428a2f98;
            7'd01: K_reg <= 32'h71374491;
            7'd02: K_reg <= 32'hb5c0fbcf;
            7'd03: K_reg <= 32'he9b5dba5;
            7'd04: K_reg <= 32'h3956c25b;
            7'd05: K_reg <= 32'h59f111f1;
            7'd06: K_reg <= 32'h923f82a4;
            7'd07: K_reg <= 32'hab1c5ed5;
            7'd08: K_reg <= 32'hd807aa98;
            7'd09: K_reg <= 32'h12835b01;
            7'd10: K_reg <= 32'h243185be;
            7'd11: K_reg <= 32'h550c7dc3;
            7'd12: K_reg <= 32'h72be5d74;
            7'd13: K_reg <= 32'h80deb1fe;
            7'd14: K_reg <= 32'h9bdc06a7;
            7'd15: K_reg <= 32'hc19bf174;
            7'd16: K_reg <= 32'he49b69c1;
            7'd17: K_reg <= 32'hefbe4786;
            7'd18: K_reg <= 32'h0fc19dc6;
            7'd19: K_reg <= 32'h240ca1cc;
            7'd20: K_reg <= 32'h2de92c6f;
            7'd21: K_reg <= 32'h4a7484aa;
            7'd22: K_reg <= 32'h5cb0a9dc;
            7'd23: K_reg <= 32'h76f988da;
            7'd24: K_reg <= 32'h983e5152;
            7'd25: K_reg <= 32'ha831c66d;
            7'd26: K_reg <= 32'hb00327c8;
            7'd27: K_reg <= 32'hbf597fc7;
            7'd28: K_reg <= 32'hc6e00bf3;
            7'd29: K_reg <= 32'hd5a79147;
            7'd30: K_reg <= 32'h06ca6351;
            7'd31: K_reg <= 32'h14292967;
            7'd32: K_reg <= 32'h27b70a85;
            7'd33: K_reg <= 32'h2e1b2138;
            7'd34: K_reg <= 32'h4d2c6dfc;
            7'd35: K_reg <= 32'h53380d13;
            7'd36: K_reg <= 32'h650a7354;
            7'd37: K_reg <= 32'h766a0abb;
            7'd38: K_reg <= 32'h81c2c92e;
            7'd39: K_reg <= 32'h92722c85;
            7'd40: K_reg <= 32'ha2bfe8a1;
            7'd41: K_reg <= 32'ha81a664b;
            7'd42: K_reg <= 32'hc24b8b70;
            7'd43: K_reg <= 32'hc76c51a3;
            7'd44: K_reg <= 32'hd192e819;
            7'd45: K_reg <= 32'hd6990624;
            7'd46: K_reg <= 32'hf40e3585;
            7'd47: K_reg <= 32'h106aa070;
            7'd48: K_reg <= 32'h19a4c116;
            7'd49: K_reg <= 32'h1e376c08;
            7'd50: K_reg <= 32'h2748774c;
            7'd51: K_reg <= 32'h34b0bcb5;
            7'd52: K_reg <= 32'h391c0cb3;
            7'd53: K_reg <= 32'h4ed8aa4a;
            7'd54: K_reg <= 32'h5b9cca4f;
            7'd55: K_reg <= 32'h682e6ff3;
            7'd56: K_reg <= 32'h748f82ee;
            7'd57: K_reg <= 32'h78a5636f;
            7'd58: K_reg <= 32'h84c87814;
            7'd59: K_reg <= 32'h8cc70208;
            7'd60: K_reg <= 32'h90befffa;
            7'd61: K_reg <= 32'ha4506ceb;
            7'd62: K_reg <= 32'hbef9a3f7;
            7'd63: K_reg <= 32'hc67178f2;
            default: K_reg <= 32'b0;
        endcase
    end

endmodule


