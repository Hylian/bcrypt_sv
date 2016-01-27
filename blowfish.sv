module round (
  input logic start, clk, reset_l,
  input logic [31:0] feistel_in, // address of S-box in F function
  input logic [31:0] p_in, // address of P-box in blfrnd

  // S-box interface
  input logic [31:0] S_data,
  inout [31:0] S_addr,

  // P-box interface
  input logic [31:0] P_data,
  inout [31:0] P_addr,

  output logic [31:0] result,
  output logic done
);

  enum logic [2:0]
  {
    WAIT,
    F_1,
    F_2,
    F_3,
    F_4,
    P_1,
    DONE
  } state, nextState;

  logic [31:0] feistel_in_reg, p_in_reg;

  /*
   * result = (((f_op1 + f_op2) ^ f_op3) + f_op4) ^ P[p_in]
   * where...
   * f_op1 = S[{24'h0, feistel_in[31:24]}]
   * f_op2 = S[{24'h1, feistel_in[23:16]}]
   * f_op3 = S[{24'h2, feistel_in[15:8]}]
   * f_op4 = S[{24'h3, feistel_in[7:0]}]
   */

  always_comb begin
    nextState = state;
    done = 0;
    S_addr = 32'hz;
    P_addr = 32'hz;

    case(state)
      WAIT: begin
        if(start) nextState = F_1;
      end
      F_1: begin
        nextState = F_2;
        S_addr = {24'h0, feistel_in_reg[31:24]};
      end
      F_2: begin
        nextState = F_3;
        S_addr = {24'h1, feistel_in_reg[23:16]};
      end
      F_3: begin
        nextState = F_4;
        S_addr = {24'h2, feistel_in_reg[15:8]};
      end
      F_4: begin
        nextState = P_1;
        S_addr = {24'h1, feistel_in_reg[7:0]};
      end
      P_1: begin
        nextState = DONE;
        P_addr = p_in_reg;
      end
      DONE: begin
        nextState = WAIT;
        done = 1;
      end
      default:
    endcase
  end

  always_ff @(posedge clk) begin
    if(~reset_l) begin
      state <= nextState;

      case(state)
        WAIT: begin
          if(start) begin
            feistel_in_reg <= feistel_in;
            p_in_reg <= p_in;
          end
        end
        F_1: begin
          result <= S_data;
        end
        F_2: begin
          result <= result + S_data;
        end
        F_3: begin
          result <= result ^ S_data;
        end
        F_4: begin
          result <= result + S_data;
        end
        P_1: begin
          result <= result ^ P_data;
        end
      endcase
    end
  end
  else begin
    state <= WAIT;
    result <= 0;
  end

endmodule: round

module encipher (
  input logic start, clk, reset_l,
  input logic [31:0] xl_in, xr_in,
  input logic [31:0] S_data, P_data,
  inout [31:0] S_addr, P_addr,
  output logic [31:0] xl_out, xr_out
  output logic done
); 

  enum logic [1:0]
  {
    WAIT,
    ROUND_START,
    ROUND_WAIT,
    DONE
  } state, nextState;

  logic [0:4] round_counter;
  logic [31:0] Xl, Xr;
  logic [31:0] round_feistel_in, round_p_in, round_result;
  logic round_start, round_done;

  round r0 (round_start, clk, reset_l, round_feistel_in, round_p_in, S_data, S_addr, P_data, P_addr, round_result, round_done);

  always_comb begin

    nextState = state;
    round_p_in = round_counter;
    round_feistel_in = (round_counter[0]) ? Xl : Xr;
    round_start = 0;
    done = 0;

    S_addr = 32'hz;
    P_addr = 32'hz;

    case(state)
      WAIT: begin
	if(start) begin
	  nextState = ROUNDS;
	  P_addr = 0;
	end
      end
      ROUND_START: begin
	nextState = ROUND_WAIT;
	round_start = 1;
      end
      ROUND_WAIT: begin
	if(round_done) begin
	  if(round_counter == 16) begin
	    nextState = DONE;
	    P_addr = 17;
	  end
	  else begin
	    nextState = ROUND_START;
	  end
	end
      end
      DONE: begin
	done = 1;
      end
    endcase

  end

  always_ff @(posedge clk) begin
    if(~reset_l) begin
      round_counter <= 1;
      Xl <= 0;
      Xr <= 0;
      xl_out <= 0;
      xr_out <= 0;

    end
    else begin

      state <= nextState;

      case(state)
	WAIT: begin
	  if(nextState == ROUND_START) begin
	    round_counter <= 1;
	    Xl <= xl_in ^ P_data; // Xl ^ p[0]
	    Xr <= xr_in;
	  end
	end
	ROUND_WAIT: begin
	  if(ROUND_START) begin
	    if(round_counter[0]) begin
	      Xr <= Xr ^ round_result; end
	    else begin
	      Xl <= Xl ^ round_result;
	    end
	    round_counter <= round_counter + 1;
	  end
	  else if(nextState == DONE) begin
	    xl_out <= Xr ^ P_data; // Xr ^ P[17]
	    xr_out <= Xl ^ round_result; // We need to include result of last round
	  end
	end
      endcase

    end

  end

endmodule: encipher
