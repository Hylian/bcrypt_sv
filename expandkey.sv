module expandKey(
  clk, reset_l, start,
  L, R,
  addr, data, cs, we, oe,
  result, done
);

  parameter P_ARRAY_OFFSET = 4000;

  /* Inputs */
  input logic clk, reset_l, start;
  input logic [31:0] L, R;

  /* SRAM A Interface */
  inout logic [31:0] data_a;
  output logic [11:0] addr_a;
  output logic cs_a_l, we_a_l, oe_a_l;

  /* SRAM B Interface */
  inout logic [31:0] data_b;
  output logic [11:0] addr_b;
  output logic cs_b_l, we_b_l, oe_b_l;

  /* Outputs */
  output logic [63:0] result;
  output logic done;

  /* Internal */
  logic [31:0] data_a_out, data_b_out;
  logic data_a_out_en, data_b_out_en;
  logic [31:0] data_a_latch, data_b_latch;
  logic [31:0] datal, datar;
  logic [4:0] init_xor_counter;

  enum logic [2:0]
  {
    WAIT,
    INIT_XOR,
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

    data_a_out_en = 0;
    data_b_out_en = 0;

    case(state)
      WAIT: begin
	if(start) begin
	  nextState = INIT_XOR_READ;
	end
      end
      INIT_XOR_READ: begin
	nextState = INIT_XOR_LATCH;
	cs_a_l = 0;
	cs_b_l = 0;
	addr_a = P_ARRAY_OFFSET + init_xor_counter;
	addr_b = P_ARRAY_OFFSET + init_xor_counter + 1;
      end
      INIT_XOR_LATCH: begin
	nextState = INIT_XOR_WRITE;
      end
      INIT_XOR_WRITE: begin
	nextState = (init_xor_counter < 5'd16) ? INIT_XOR_READ : XOR_PARRAY_1A;
	cs_a_l = 0;
	cs_b_l = 0;
	oe_a_l = 1;
	oe_b_l = 1;
	we_a_l = 0;
	we_b_l = 0;
	data_a_out = data_a_latch;
	data_b_out = data_b_latch;
	data_a_out_en = 1;
	data_b_out_en = 1;
	addr_a = P_ARRAY_OFFSET + init_xor_counter;
	addr_b = P_ARRAY_OFFSET + init_xor_counter + 1;
      end
      XOR_PARRAY_1A: begin
	nextState = XOR_PARRAY_1A_WAIT;
	feistel_datal = salt[127:96] ^ datal;
	feistel_datar = salt[95:64] ^ datar;
	feistel_start = 1;
      end
      XOR_PARRAY_1A_WAIT: begin
	if(feistel_done) begin
	  nextState = XOR_PARRAY_1B;
	end
      end
      XOR_PARRAY_1B: begin
	nextState = XOR_PARRAY_1B_WAIT;
	feistel_datal = salt[63:32] ^ datal;
	feistel_datar = salt[31:0] ^ datar;
	feistel_start = 1;
      end
      XOR_PARRAY_1B_WAIT: begin
	if(feistel_done) begin
	  nextState = XOR_PARRAY_2;
	end
      end
      XOR_PARRAY_2: begin
	if(xor_parray_counter < 16) begin
	  nextState = XOR_PARRAY_1A;
	end
	else begin
	  nextState = XOR_SBOX_1;
	end
	cs_a_l = 0;
	cs_b_l = 0;
	oe_a_l = 1;
	oe_b_l = 1;
	we_a_l = 0;
	we_b_l = 0;
	data_a_out = datal;
	data_b_out = datar;
	data_a_out_en = 1;
	data_b_out_en = 1;
	addr_a = P_ARRAY_OFFSET + xor_parray_counter;
	addr_b = P_ARRAY_OFFSET + xor_parray_counter + 1;
      end
      XOR_SBOX_1A: begin
	nextState = XOR_SBOX_1B_WAIT;
	feistel_datal = salt[127:96] ^ datal;
	feistel_datar = salt[63:32] ^ datar;
	feistel_start = 1;

      end
      XOR_SBOX_1A_WAIT: begin
	if(feistel_done) begin
	  nextState = XOR_SBOX_1B;
	end
      end
      XOR_SBOX_1B: begin
	if(xor_sbox_counter == 1022) begin
	  nextState = DONE;
	end
	else begin
	  nextState = XOR_SBOX_1A;
	end

	cs_a_l = 0;
	cs_b_l = 0;
	oe_a_l = 1;
	oe_b_l = 1;
	we_a_l = 0;
	we_b_l = 0;
	data_a_out = datal;
	data_b_out = datar;
	data_a_out_en = 1;
	data_b_out_en = 1;
	addr_a = xor_sbox_counter;
	addr_b = xor_sbox_counter + 1;
      end

   endcase
  end

  always_ff @(posedge clk) begin
    if(~reset) begin
      result <= 0;
    end
    else begin
      state <= nextState;

      case(state)
	WAIT: begin
	  round_counter <= 0;
	  init_xor_counter <= 0;
	end
	INIT_XOR_LATCH: begin
	  data_a_latch <= data_a ^ {key[key_index], key[key_index+1], key[key_index+2], key[key_index+3]};
	  data_b_latch <= data_b ^ {key[key_index+4], key[key_index+5], key[key_index+6], key[key_index+7]};
	end
	INIT_XOR_WRITE: begin
	  init_xor_counter <= init_xor_counter + 2;
	  if(nextState == XOR_PARRAY_1A) begin
	    datal <= 0;
	    datar <= 0;
	  end
	end
	XOR_PARRAY_1A_WAIT: begin
	  if(feistel_done) begin
	    datal <= feistel_resultl;
	    datar <= feistel_resultr;
	  end
	end
	XOR_PARRAY_1B_WAIT: begin
	  if(feistel_done) begin
	    datal <= feistel_resultl;
	    datar <= feistel_resultr;
	  end
	end
	XOR_PARRAY_2: begin
	  if(nextState == XOR_PARRAY_1A) begin
	    xor_parray_counter <= xor_parray_counter + 2;
	  end
	  else begin
	    xor_sbox_counter <= 0;
	  end
	end
	XOR_SBOX_1B: begin
	  if(xor_sbox_counter == 1022) begin
	    salt <= 0; //todo figure out what this is and if we need it
	  end
	  else begin
	    xor_sbox_counter <= xor_sbox_counter + 2;
	  end
	end
      endcase
    end
  end


endmodule: feistel
