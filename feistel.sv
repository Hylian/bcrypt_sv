module feistel(
  clk, reset_l, start,
  L, R,
  addr_a, data_a, cs_a_l, we_a_l, oe_a_l,
  addr_b, data_b, cs_b_l, we_b_l, oe_b_l,
  resultL, resultR, done
);

  parameter P_ARRAY_OFFSET = 4000;

  /* Inputs */
  input logic clk, reset_l, start;
  input logic [31:0] L, R;

  /* SRAM A Interface */
  input logic [31:0] data_a;
  output logic [11:0] addr_a;
  output logic cs_a_l, we_a_l, oe_a_l;

  /* SRAM B Interface */
  input logic [31:0] data_b;
  output logic [11:0] addr_b;
  output logic cs_b_l, we_b_l, oe_b_l;

  /* Outputs */
  output logic [31:0] resultL, resultR;
  output logic done;

  /* Internal */
  logic [31:0] F_r;

  enum logic [2:0]
  {
    WAIT,
    INIT,
    F1,
    F2,
    XOR_P17,
    DONE
  } state, nextState;

  always_comb begin
    nextState = state;
    done = 0;

    cs_a_l = 1;
    we_a_l = 1;
    oe_a_l = 0;

    cs_b_l = 1;
    we_b_l = 1;
    oe_b_l = 0;

    case(state)
      WAIT: begin
	if(start) begin
	  nextState = INIT;
	  cs_a_l = 0;
	  addr = 0;
	end
      end
      INIT: begin
	nextState = F1A;
	cs_a_l = 0;
	cs_b_l = 0;
	addr_a = L[31:24];
	addr_b = L[23:16] + 256; // add a leading 1
      end
      F1: begin
	nextState = F2;
	cs_a_l = 0;
	cs_b_l = 0;
	addr_a = L[15:8] + 512;
	addr_b = L[7:0] + 768;
      end
      F2: begin
	if(round_counter < 15) begin
	  nextState = INIT;
	  cs_a_l = 0;
	  addr_a = round_counter + 1;
	end
	else begin
	  nextState = XOR_P17;
	  cs_a_l = 0;
	  cs_b_l = 0;
	  addr_a = P_ARRAY_OFFSET + 17;
	  addr_a = P_ARRAY_OFFSET + 16;
	end
      end
      XOR_P17: begin
	nextState = WAIT;
	done = 1;
      end
    endcase
  end

  always_ff @(posedge clk) begin
    if(~reset) begin
      result <= 0;
      round_counter <= 0; //optional
      F_r <= 0; //optional
    end
    else begin
      state <= nextState;

      case(state)
	WAIT: begin
	  round_counter <= 0;
	end
	INIT: begin
	  L <= L ^ data_a; // L ^= p[round_counter]
	end
	F1: begin
	  F_r <= data_a + data_b; // F_r = s[L[31:24]] + s[256+L[23:16]]
	end
	F2: begin
	  R <= L;
	  L <= R^((F_r ^ data_a) + data_b); 
	  // L = R^(((s[L[31:24]] + s[256+L[23:16]]) ^ s[512+L[15:8]) + s[768+L[7:0])
	  if(round_counter < 15) begin
	    round_counter <= round_counter + 1;
	  end
	end
	XOR_P17: begin
	  resultL <= R ^ data_a;
	  resultR <= L ^ data_b;
	end
      endcase
    end
  end


endmodule: feistel
