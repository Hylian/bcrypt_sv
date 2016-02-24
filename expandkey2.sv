module expandKey(
  clk, reset_l, start, use_salt,
  salt, key,
  s1_out, s1_in, s1_addr, s1_cs_l, s1_we_l,
  s2_out, s2_in, s2_addr, s2_cs_l, s2_we_l,
  s3_out, s3_in, s3_addr, s3_cs_l, s3_we_l,
  s4_out, s4_in, s4_addr, s4_cs_l, s4_we_l,
  p_data, p_addr, 
  result, done
);

  /* Inputs */
  input logic clk, reset_l, start, use_salt;
  input logic [127:0] salt;
  input logic [575:0] key;

  /* SRAM Interface */
  input logic [31:0] s1_out, s2_out, s3_out, s4_out;
  output logic [31:0] s1_in, s2_in, s3_in, s4_in;
  output logic [7:0] s1_addr, s2_addr, s3_addr, s4_addr;
  output logic s1_cs_l, s2_cs_l, s3_cs_l, s4_cs_l;
  output logic s1_we_l, s2_we_l, s3_we_l, s4_we_l;

  /* Outputs */
  output logic [63:0] result;
  output logic done;

  /* Feistel module interface */
  logic f1_start, f1_done;
  logic f1_s1_out, f1_s1_addr, f1_s1_cs_l;
  logic f1_s2_out, f1_s2_addr, f1_s2_cs_l;
  logic f1_s3_out, f1_s3_addr, f1_s3_cs_l;
  logic f1_s4_out, f1_s4_addr, f1_s4_cs_l;
  logic [31:0] f1_L, f1_R, f1_resultL, f1_resultR;
  logic f1_sram_mux;

  assign f1_s1_out = s1_out;
  assign f1_s2_out = s2_out;
  assign f1_s3_out = s3_out;
  assign f1_s4_out = s4_out;

  mux2to1 #(32) m_salt_L (m_salt_L_sel, salt[0:31], salt[64:95], m_salt_L_out);
  mux2to1 #(32) m_salt_R (m_salt_R_sel, salt[32:63], salt[96:127], m_salt_R_out);

  xorer #(32) x_L (m_salt_L_out, f1_resultL, x_L_out);
  xorer #(32) x_R (m_salt_R_out, f1_resultR, x_R_out);

  mux2to1 #(32) m_f_L (use_salt, f1_resultL, x_L_out, m_f_L_out);
  mux2to1 #(32) m_f_R (use_salt, f1_resultR, x_R_out, m_f_R_out);

  feistel f1 (clk, f1_reset_l, f1_start, m_f_L_out, m_f_R_out, 
	      f1_s1_out, f1_s1_addr, f1_s1_cs_l,
	      f1_s2_out, f1_s2_addr, f1_s2_cs_l,
	      f1_s3_out, f1_s3_addr, f1_s3_cs_l,
	      f1_s4_out, f1_s4_addr, f1_s4_cs_l,
	      f1_resultL, f1_resultR, f1_done);

  mux2to1 #(32) m_f_sp (m_f_sp_sel, f1_resultL, f1_resultR, m_f_sp_out);

  assign s1_in = m_f_sp_out;
  assign s2_in = m_f_sp_out;
  assign s3_in = m_f_sp_out;
  assign s4_in = m_f_sp_out;

  register #(576) r_p (clk, reset_l, m_r_p_out, r_p_out); // 18 * 32-bit reg array
  mux2to1 #(576) m_r_p (m_r_p_sel, r_p_out, r_p_xor, m_r_p_out);
  xorer #(32) x_P0 (r_p_out[0:31], key[0:31], r_p_xor[0:31]);
  xorer #(32) x_P1 (r_p_out[32:63], key[32:63], r_p_xor[32:63]);
  xorer #(32) x_P2 (r_p_out[64:95], key[64:95], r_p_xor[64:95]);
  xorer #(32) x_P3 (r_p_out[96:127], key[96:127], r_p_xor[96:127]);
  xorer #(32) x_P4 (r_p_out[128:159], key[128:159], r_p_xor[128:159]);
  xorer #(32) x_P5 (r_p_out[160:191], key[160:191], r_p_xor[160:191]);
  xorer #(32) x_P6 (r_p_out[192:223], key[192:223], r_p_xor[192:223]);
  xorer #(32) x_P7 (r_p_out[224:255], key[224:255], r_p_xor[224:255]);
  xorer #(32) x_P8 (r_p_out[256:287], key[256:287], r_p_xor[256:287]);
  xorer #(32) x_P9 (r_p_out[288:319], key[288:319], r_p_xor[288:319]);
  xorer #(32) x_P10 (r_p_out[320:351], key[320:351], r_p_xor[320:351]);
  xorer #(32) x_P11 (r_p_out[352:383], key[352:383], r_p_xor[352:383]);
  xorer #(32) x_P12 (r_p_out[384:415], key[384:415], r_p_xor[384:415]);
  xorer #(32) x_P13 (r_p_out[416:447], key[416:447], r_p_xor[416:447]);
  xorer #(32) x_P14 (r_p_out[448:479], key[448:479], r_p_xor[448:479]);
  xorer #(32) x_P15 (r_p_out[480:511], key[480:511], r_p_xor[480:511]);
  xorer #(32) x_P16 (r_p_out[512:543], key[512:543], r_p_xor[512:543]);
  xorer #(32) x_P17 (r_p_out[544:575], key[544:575], r_p_xor[544:575]);

  register #(8) r_round (clk, r_round_reset_l, m_r_round_out, r_round_out); // 18 * 32-bit reg array
  mux2to1 #(8) m_r_round (m_r_round_sel, r_round_out, a_r_round_out, m_r_round_out);
  adder #(8) a_r_round (r_round_out, 1, a_r_round_out;

  register #(1) r_salt_half (clk, r_salt_half_reset_l, m_r_salt_half_out, r_salt_half_out);
  mux2to1 #(1) m_r_salt_half (m_r_salt_half_sel, r_salt_half_out, not(r_salt_half_out), m_r_salt_half_out);

  assign m_salt_L_sel = r_salt_half_out;
  assign m_salt_R_sel = r_salt_half_out;

  enum logic [3:0]
  {
    WAIT,
    XOR_KEY_P,
    ENC_P,
    ENC_P_WAIT,
    ENC_S1,
    ENC_S1_WAIT,
    ENC_S2,
    ENC_S2_WAIT,
    ENC_S3,
    ENC_S3_WAIT,
    ENC_S4,
    ENC_S4_WAIT,
    DONE
  } state, nextState;
 
  always_comb begin
    nextState = state;
    done = 0;

    r_round_reset_l = 1;
    r_salt_half_reset_l = 1;

    m_r_salt_half_sel = 0; // hold salt half by default
    m_r_p_sel = 0; // hold P by default

    f1_reset_l = 1;

    case(state)
      WAIT: begin
	if(start) begin
	  r_round_reset_l = 0;
	  nextState = XOR_KEY_P;
	end
      end
      XOR_KEY_P: begin
	nextState = ENC_P;
	r_salt_half_reset_l = 0; // reset salt half bit
	m_r_p_sel = 1; // P <= P ^ key
	f1_reset_l = 0;
      end
      ENC_P: begin
	nextState = ENC_P_WAIT;
	f1_start = 1;
      end
      ENC_P_WAIT: begin
	if(f1_done) begin
	  if(r_round_out == 17) begin
	    nextState = ENC_P;
	  end
	  else begin
	    nextState = ENC_S1;
	    r_round_reset_l = 0;
	  end
	end
	else begin
	  nextState = ENC_P_WAIT;
	end
      end
   endcase
  end

endmodule: expandKey
