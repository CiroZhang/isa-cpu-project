// Data memory (RAM)
// 256 entries of 8-bit data
// Write: clocked, when enable=1
// Read:  combinational
module dat_mem (
  input  logic       clk,
  input  logic       enable,
  input  logic [7:0] addr,
  input  logic [7:0] data_in,
  output logic [7:0] data_out
);

  logic [7:0] core [256];

  // write on clock edge
  always_ff @(posedge clk)
    if (enable) core[addr] <= data_in;

  // read combinationally
  assign data_out = core[addr];

endmodule
