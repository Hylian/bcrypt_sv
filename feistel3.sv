module feistel(
  clk, reset_l, start,
  L, R,
  s1_out, s1_addr, s1_cs_l,
  s2_out, s2_addr, s2_cs_l,
  s3_out, s3_addr, s3_cs_l,
  s4_out, s4_addr, s4_cs_l,
  p_out, p_addr, p_cs_l,
  resultL, resultR, done
);

  /* Inputs */
  input logic clk, reset_l, start;
  input logic [31:0] L, R;

  /* SRAM Interface */
  input logic [31:0] s1_out, s2_out, s3_out, s4_out, p_out;
  output logic [7:0] s1_addr, s2_addr, s3_addr, s4_addr, p_addr;
  output logic s1_cs_l, s2_cs_l, s3_cs_l, s4_cs_l, p_cs_l;

  /* Outputs */
  output logic [31:0] resultL, resultR;
  output logic done;

  enum logic [3:0]
  {
    WAIT,
    XOR_P0_WAIT0,
    XOR_P0_WAIT1,
    FR_INIT,
    FR_WAIT,
    FR_SWAP,
    XOR_P17,
    XOR_P17_WAIT0,
    XOR_P17_WAIT1,
    DONE
  } state, nextState;

  /* Internal */
  logic [31:0] a1_out, a2_out, x1_out, x2_out;
  logic [31:0] m_add_out, m_xor_out, m_L_out, m_R_out;
  logic [31:0] r_L_out, r_R_out;
  logic m_add_sel, m_xor_sel, m_round_sel;
  logic [1:0] m_L_sel, m_R_sel;
  logic [4:0] r_round_out, a_round_out, m_round_out;
  logic r_round_reset_l;
  
  adder #(32) a1 (s1_out, s2_out, a1_out);
  xorer #(32) x1 (a1_out, s3_out, x1_out);
  adder #(32) a2 (x1_out, s4_out, a2_out);
  mux2to1 #(32) m_add (m_add_sel, 0, a2_out, m_add_out);
  mux2to1 #(32) m_xor (m_xor_sel, r_L_out, r_R_out, m_xor_out);
  xorer3 #(32) x2 (m_add_out, p_out, m_xor_out, x2_out);

  mux3to1 #(32) m_L (m_L_sel, r_L_out, L, x2_out, m_L_out);
  mux3to1 #(32) m_R (m_R_sel, r_R_out, R, r_L_out, m_R_out);

  register #(32) r_L (clk, reset_l, m_L_out, r_L_out);
  register #(32) r_R (clk, reset_l, m_R_out, r_R_out);

  register #(5) r_round (clk, r_round_reset_l, m_round_out, r_round_out);
  adder #(5) a_round (r_round_out, 5'h1, a_round_out);
  mux2to1 #(5) m_round (m_round_sel, r_round_out, a_round_out, m_round_out);

  always_comb begin
    nextState = state;
    done = 0;

    s1_cs_l = 1;
    s2_cs_l = 1;
    s3_cs_l = 1;
    s4_cs_l = 1;
    p_cs_l = 1;

    m_xor_sel = 0;
    m_add_sel = 0;

    r_round_reset_l = 1;

    // Default to loopback (hold value)
    m_L_sel = 0;
    m_R_sel = 0;
    m_round_sel = 0;

    case(state)
      WAIT: begin
	if(start) begin
	  nextState = XOR_P0_WAIT0;
	  p_cs_l = 0;
	  p_addr = 0;
	  m_L_sel = 1; // load L
	  m_R_sel = 1; // load R
	end
      end
      XOR_P0_WAIT0: begin
	nextState = XOR_P0_WAIT1;
      end
      XOR_P0_WAIT1: begin
	nextState = FR_INIT;
	m_add_sel = 0; // 0
	m_xor_sel = 0; // L
	m_L_sel = 2; // L <= p[0] ^ L
	r_round_reset_l = 0; // round <= 0
      end
      FR_INIT: begin
	nextState = FR_WAIT;

	s1_cs_l = 0;
	s2_cs_l = 0;
	s3_cs_l = 0;
	s4_cs_l = 0;
	p_cs_l = 0;

	s1_addr = r_L_out[31:24];
	s2_addr = r_L_out[23:16];
	s3_addr = r_L_out[15:8];
	s4_addr = r_L_out[7:0];
	p_addr = r_round_out;
      end
      FR_WAIT: begin
	nextState = FR_SWAP;
      end
      FR_SWAP: begin
	if(r_round_out == 15) begin
	  nextState = XOR_P17;
	end
	else begin
	  nextState = FR_INIT;
	end

	m_round_sel = 1; // round++

	// L = Fr ^ R;
	m_add_sel = 1; // adder output
	m_xor_sel = 1; // R
	m_L_sel = 2; // xor output

	// R = L
	m_R_sel = 2; // L
      end
      XOR_P17: begin
	nextState = XOR_P17_WAIT0;
	p_cs_l = 0;
	p_addr = 17;
      end
      XOR_P17_WAIT0: begin
	nextState = XOR_P17_WAIT1;
      end
      XOR_P17_WAIT1: begin
	nextState = DONE;

	m_add_sel = 0; // 0
	m_xor_sel = 1; // R
	m_L_sel = 2; // L <= p[17] ^ R
      end
      DONE: begin
	nextState = WAIT;
	done = 1;
      end
    endcase
  end

endmodule: feistel
