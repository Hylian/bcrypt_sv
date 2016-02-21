module register (clk, reset_l, D, Q);
  parameter WIDTH = 32;

  input logic clk, reset_l;
  input logic [WIDTH-1:0] D;
  output logic [WIDTH-1:0] Q;

  always_ff @(posedge clk, negedge reset_l) begin
    if(!reset_l) begin
      Q <= 0;
    end
    else if(clk) begin
      Q <= D;
    end
  end
  
endmodule: register

module adder (A, B, result);
  parameter WIDTH = 32;

  input logic [WIDTH-1:0] A, B;
  output logic [WIDTH-1:0] result;

  assign result = A + B;
endmodule: adder 

module xorer (A, B, result);
  parameter WIDTH = 32;

  input logic [WIDTH-1:0] A, B;
  output logic [WIDTH-1:0] result;

  assign result = A ^ B;
endmodule: xorer

module xorer3 (A, B, C, result);
  parameter WIDTH = 32;

  input logic [WIDTH-1:0] A, B, C;
  output logic [WIDTH-1:0] result;

  assign result = A ^ B ^ C;
endmodule: xorer3

module mux2to1 (sel, A, B, out);
  parameter WIDTH = 32;

  input logic sel;
  input logic [WIDTH-1:0] A, B;
  output logic [WIDTH-1:0] out;

  assign out = sel ? B : A;
endmodule: mux2to1

module mux3to1 (sel, A, B, C, out);
  parameter WIDTH = 32;

  input logic [1:0] sel;
  input logic [WIDTH-1:0] A, B, C;
  output logic [WIDTH-1:0] out;

  always_comb begin
    case(sel)
      0: out = A;
      1: out = B;
      2: out = C;
    endcase
  end
endmodule: mux3to1
