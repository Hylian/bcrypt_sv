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
  input logic [4:0] p_addr;

  /* SRAM Interface */
  input logic [31:0] s1_out, s2_out, s3_out, s4_out;
  output logic [31:0] s1_in, s2_in, s3_in, s4_in;
  output logic [7:0] s1_addr, s2_addr, s3_addr, s4_addr;
  output logic s1_cs_l, s2_cs_l, s3_cs_l, s4_cs_l;
  output logic s1_we_l, s2_we_l, s3_we_l, s4_we_l;

  /* Outputs */
  output logic [63:0] result;
  output logic [7:0] p_data;
  output logic done;

  /* Feistel module interface */
  logic f1_start, f1_reset_l, f1_done;
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

  logic [31:0] m_salt_L_out, m_salt_R_out;

  mux2to1 #(32) m_salt_L (m_salt_L_sel, salt[31:0], salt[95:64], m_salt_L_out);
  mux2to1 #(32) m_salt_R (m_salt_R_sel, salt[63:32], salt[127:96], m_salt_R_out);

  logic [31:0] x_L_out, x_R_out;
  xorer #(32) x_L (m_salt_L_out, f1_resultL, x_L_out);
  xorer #(32) x_R (m_salt_R_out, f1_resultR, x_R_out);

  logic [31:0] m_f_L_out, m_f_R_out;
  mux2to1 #(32) m_f_L (use_salt, f1_resultL, x_L_out, m_f_L_out);
  mux2to1 #(32) m_f_R (use_salt, f1_resultR, x_R_out, m_f_R_out);

/*
  feistel f1 (clk, f1_reset_l, f1_start, m_f_L_out, m_f_R_out, 
	      f1_s1_out, f1_s1_addr, f1_s1_cs_l,
	      f1_s2_out, f1_s2_addr, f1_s2_cs_l,
	      f1_s3_out, f1_s3_addr, f1_s3_cs_l,
	      f1_s4_out, f1_s4_addr, f1_s4_cs_l,
	      f1_resultL, f1_resultR, f1_done);
  */

  logic [31:0] m_f_sp_out;
  logic m_f_sp_sel;

  mux2to1 #(32) m_f_sp (m_f_sp_sel, f1_resultL, f1_resultR, m_f_sp_out);

  assign s1_in = m_f_sp_out;
  assign s2_in = m_f_sp_out;
  assign s3_in = m_f_sp_out;
  assign s4_in = m_f_sp_out;

  logic [575:0] r_p_out, r_p_xor, m_r_p_out;
  logic m_r_p_sel;

  register #(576) r_p (clk, reset_l, m_r_p_out, r_p_out); // 18 * 32-bit reg array
  mux2to1 #(576) m_r_p (m_r_p_sel, r_p_out, r_p_xor, m_r_p_out);
  xorer #(32) x_P0 (r_p_out[31:0], key[31:0], r_p_xor[31:0]);
  xorer #(32) x_P1 (r_p_out[63:32], key[63:32], r_p_xor[63:32]);
  xorer #(32) x_P2 (r_p_out[95:64], key[95:64], r_p_xor[95:64]);
  xorer #(32) x_P3 (r_p_out[127:96], key[127:96], r_p_xor[127:96]);
  xorer #(32) x_P4 (r_p_out[159:128], key[159:128], r_p_xor[159:128]);
  xorer #(32) x_P5 (r_p_out[191:160], key[191:160], r_p_xor[191:160]);
  xorer #(32) x_P6 (r_p_out[223:192], key[223:192], r_p_xor[223:192]);
  xorer #(32) x_P7 (r_p_out[255:224], key[255:224], r_p_xor[255:224]);
  xorer #(32) x_P8 (r_p_out[287:256], key[287:256], r_p_xor[287:256]);
  xorer #(32) x_P9 (r_p_out[319:288], key[319:288], r_p_xor[319:288]);
  xorer #(32) x_P10 (r_p_out[351:320], key[351:320], r_p_xor[351:320]);
  xorer #(32) x_P11 (r_p_out[383:352], key[383:352], r_p_xor[383:352]);
  xorer #(32) x_P12 (r_p_out[415:384], key[415:384], r_p_xor[415:384]);
  xorer #(32) x_P13 (r_p_out[447:416], key[447:416], r_p_xor[447:416]);
  xorer #(32) x_P14 (r_p_out[479:448], key[479:448], r_p_xor[479:448]);
  xorer #(32) x_P15 (r_p_out[511:480], key[511:480], r_p_xor[511:480]);
  xorer #(32) x_P16 (r_p_out[543:512], key[543:512], r_p_xor[543:512]);
  xorer #(32) x_P17 (r_p_out[575:544], key[575:544], r_p_xor[575:544]);

  logic r_round_reset_l;
  logic [7:0] m_r_round_out, r_round_out;
  register #(8) r_round (clk, r_round_reset_l, m_r_round_out, r_round_out); // 18 * 32-bit reg array
  logic m_r_round_sel;
  logic [7:0] a_r_round_out, m_r_round_out;
  mux2to1 #(8) m_r_round (m_r_round_sel, r_round_out, a_r_round_out, m_r_round_out);
  adder #(8) a_r_round (r_round_out, 8'h1, a_r_round_out);

  logic r_salt_half_reset_l;
  register #(1) r_salt_half (clk, r_salt_half_reset_l, m_r_salt_half_out, r_salt_half_out);
  logic m_r_salt_half_sel;
  mux2to1 #(1) m_r_salt_half (m_r_salt_half_sel, r_salt_half_out, !r_salt_half_out, m_r_salt_half_out);

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
    m_r_round_sel = 0; // hold round counter by default

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
