module expandKey(
  clk, reset_l, start, load_salt,
  L, R, salt,
  key_data, key_addr,
  data_out_a, data_in_a, addr_a, cs_a_l, we_a_l, oe_a_l,
  data_out_b, data_in_b, addr_b, cs_b_l, we_b_l, oe_b_l,
  result, done
);

  parameter P_ARRAY_OFFSET = 4000;

  /* Inputs */
  input logic clk, reset_l, start, load_salt;
  input logic [31:0] L, R;
  input logic [127:0] salt;

  /* Key Interface */
  input logic [7:0] key_data [8]; // upper level module gives us key[addr] through key[addr+7]
  output logic [6:0] key_addr; // we need to address up to 72 bytes

  /* SRAM A Interface */
  input logic [31:0] data_out_a;
  output logic [31:0] data_in_a;
  output logic [11:0] addr_a;
  output logic cs_a_l, we_a_l, oe_a_l;

  /* SRAM B Interface */
  input logic [31:0] data_out_b;
  output logic [31:0] data_in_b;
  output logic [11:0] addr_b;
  output logic cs_b_l, we_b_l, oe_b_l;

  /* Outputs */
  output logic [63:0] result;
  output logic done;

  /* Internal */
  logic [31:0] data_a_reg, data_b_reg;
  logic [31:0] datal, datar;
  logic [4:0] init_xor_counter;
  logic [127:0] salt_latch;
  logic [6:0] key_index;
  logic [4:0] xor_parray_counter;
  logic [9:0] xor_sbox_counter;

  /* Feistel module interface */
  logic feistel_start, feistel_done;
  logic feistel_cs_a_l, feistel_we_a_l, feistel_oe_a_l;
  logic feistel_cs_b_l, feistel_we_b_l, feistel_oe_b_l;
  logic [11:0] feistel_addr_a, feistel_addr_b;
  logic [31:0] feistel_data_out_a, feistel_data_out_b;
  logic [31:0] feistel_L, feistel_R, feistel_resultL, feistel_resultR;
  logic feistel_sram_mux;

  // Instantiate feistel module
  feistel f1 (clk, reset_l, feistel_start, feistel_L, feistel_R, 
	      feistel_data_out_a, feistel_addr_a, feistel_cs_a_l, feistel_we_a_l, feistel_oe_a_l,
	      feistel_data_out_b, feistel_addr_b, feistel_cs_b_l, feistel_we_b_l, feistel_oe_b_l, 
	      feistel_resultL, feistel_resultR, feistel_done);

  enum logic [3:0]
  {
    WAIT,
    INIT_XOR_READ,
    INIT_XOR_LATCH,
    INIT_XOR_WRITE,
    XOR_PARRAY_1A,
    XOR_PARRAY_1A_WAIT,
    XOR_PARRAY_1B,
    XOR_PARRAY_1B_WAIT,
    XOR_PARRAY_2,
    XOR_SBOX_1A,
    XOR_SBOX_1A_WAIT,
    XOR_SBOX_1B,
    DONE
  } state, nextState;
 
  always_comb begin
    nextState = state;
    done = 0;

    // Feistel interface
    feistel_start = 0;
    feistel_L = 0;
    feistel_R = 0;

    feistel_sram_mux = 0;

    if(feistel_sram_mux) begin
      // Connect SRAM interface to feistel module
      oe_a_l = feistel_oe_a_l;
      oe_b_l = feistel_we_a_l;
      we_a_l = feistel_we_a_l;
      we_b_l = feistel_we_b_l;
      cs_a_l = feistel_cs_a_l;
      cs_b_l = feistel_cs_b_l;
      feistel_data_out_a = data_out_a;
      feistel_data_out_b = data_out_b;
      addr_a = feistel_addr_a;
      addr_b = feistel_addr_b;
    end
    else begin
      // Connect SRAM interface to this module
      // Chip Select off by default
      cs_a_l = 1;
      cs_b_l = 1;

      // Write Enable off by defaut
      we_a_l = 1;
      we_b_l = 1;

      // Output Enable on by default
      oe_a_l = 0;
      oe_b_l = 0;
    end

    data_in_a = 0;
    data_in_b = 0;

    case(state)
      WAIT: begin
	if(start) begin
	  nextState = INIT_XOR_READ;
	end
      end
      /* INIT_XOR: XOR the key into the P-array (opposing endianness)*/
      INIT_XOR_READ: begin
	// Read in the next two values from the P-array
	nextState = INIT_XOR_LATCH;
	cs_a_l = 0;
	cs_b_l = 0;
	addr_a = P_ARRAY_OFFSET + init_xor_counter;
	addr_b = P_ARRAY_OFFSET + init_xor_counter + 1;
      end
      INIT_XOR_LATCH: begin
	// Compute the XOR against the key
	// Can we combine this with the next state?
	key_addr = key_index;
	nextState = INIT_XOR_WRITE;
      end
      INIT_XOR_WRITE: begin
	// Write the values back to memory
	// If we're about to write back to addr 16 and 17, exit loop
	nextState = (init_xor_counter < 5'd16) ? INIT_XOR_READ : XOR_PARRAY_1A;
	cs_a_l = 0;
	cs_b_l = 0;
	oe_a_l = 1;
	oe_b_l = 1;
	we_a_l = 0;
	we_b_l = 0;
	data_in_a = data_a_reg;
	data_in_b = data_b_reg;
	addr_a = P_ARRAY_OFFSET + init_xor_counter;
	addr_b = P_ARRAY_OFFSET + init_xor_counter + 1;
      end
      /* XOR_PARRAY: run blowfish_encipher on the salt and write it to P */
      XOR_PARRAY_1A: begin
	// Start the feistel module with top half of salt ^ data
	// datal and datar initialized to 0
	nextState = XOR_PARRAY_1A_WAIT;
	feistel_L = salt_latch[127:96] ^ datal;
	feistel_R = salt_latch[95:64] ^ datar;
	feistel_start = 1;
      end
      XOR_PARRAY_1A_WAIT: begin
	// Wait until module is done and latch result
	feistel_sram_mux = 1;
	if(feistel_done) begin
	  nextState = XOR_PARRAY_1B;
	end
      end
      XOR_PARRAY_1B: begin
	// Start the feistel module with top half of salt ^ result from feistel
	nextState = XOR_PARRAY_1B_WAIT;
	feistel_L = salt_latch[63:32] ^ datal;
	feistel_R = salt_latch[31:0] ^ datar;
	feistel_start = 1;
      end
      XOR_PARRAY_1B_WAIT: begin
	// Wait until module is done and latch result
	feistel_sram_mux = 1;
	if(feistel_done) begin
	  nextState = XOR_PARRAY_2;
	end
      end
      XOR_PARRAY_2: begin
	// Write the results back to the P array
	// Loop XOR_PARRAY until we've done 17 ops
	if(xor_parray_counter < 16) begin
	  nextState = XOR_PARRAY_1A;
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
	data_in_a = datal;
	data_in_b = datar;
	addr_a = P_ARRAY_OFFSET + xor_parray_counter;
	addr_b = P_ARRAY_OFFSET + xor_parray_counter + 1;
      end
      /* XOR_SBOX: run blowfish_encipher on the salt and write it to S */
      XOR_SBOX_1A: begin
	// Start the feistel module with top half of salt ^ result from feistel
	nextState = XOR_SBOX_1A_WAIT;
	feistel_L = salt_latch[127:96] ^ datal;
	feistel_R = salt_latch[63:32] ^ datar;
	feistel_start = 1;
      end
      XOR_SBOX_1A_WAIT: begin
	// Wait until module is done and latch result
	feistel_sram_mux = 1;
	if(feistel_done) begin
	  nextState = XOR_SBOX_1B;
	end
      end
      XOR_SBOX_1B: begin
	//If we're doing the 1022+1023 writeback, we're done
	if(xor_sbox_counter == 1022) begin
	  nextState = DONE;
	end
	//Else, we keep looping
	else begin
	  nextState = XOR_SBOX_1A;
	end

	cs_a_l = 0;
	cs_b_l = 0;
	oe_a_l = 1;
	oe_b_l = 1;
	we_a_l = 0;
	we_b_l = 0;
	data_in_a = datal;
	data_in_b = datar;
	addr_a = xor_sbox_counter;
	addr_b = xor_sbox_counter + 1;
      end

   endcase
  end

  always_ff @(posedge clk) begin
    if(~reset_l) begin
      result <= 0;
      salt_latch <= 0;
    end
    else begin
      state <= nextState;

      case(state)
	WAIT: begin
	  init_xor_counter <= 0;
	  if(load_salt) begin
	    salt_latch <= salt;
	  end
	end
	INIT_XOR_LATCH: begin
	  //data_a_reg <= data_a ^ {key[key_index], key[key_index+1], key[key_index+2], key[key_index+3]};
	  //data_b_reg <= data_b ^ {key[key_index+4], key[key_index+5], key[key_index+6], key[key_index+7]};

	  data_a_reg <= data_out_a ^ {key_data[0], key_data[1], key_data[2], key_data[3]};
	  data_b_reg <= data_out_b ^ {key_data[4], key_data[5], key_data[6], key_data[7]};
	  key_index <= key_index + 8;
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
	    datal <= feistel_resultL;
	    datar <= feistel_resultR;
	  end
	end
	XOR_PARRAY_1B_WAIT: begin
	  if(feistel_done) begin
	    datal <= feistel_resultL;
	    datar <= feistel_resultR;
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
	    salt_latch <= 0; //todo figure out what this is and if we need it
	  end
	  else begin
	    xor_sbox_counter <= xor_sbox_counter + 2;
	  end
	end
      endcase
    end
  end
endmodule: expandKey
