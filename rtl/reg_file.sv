// Register file
// Read:  combinational, any of R0-R7 via rs_addr (3-bit)
//        combinational, any of R0-R7 via rd_addr (3-bit)
// Write: clocked, writes data_in into R0-R7 via wr_addr (3-bit) when enable=1
// wr_addr is separate from rd_addr so ADDX/SUBX can read Rd (R0-R3)
// while writing to R(4+d) (R4-R7)
module reg_file (
  input  logic       clk,
  input  logic       enable,

  input  logic [7:0] data_in,

  input  logic [2:0] rs_addr,
  input  logic [2:0] rd_addr,   // read address for Rd operand
  input  logic [2:0] wr_addr,   // write address (may differ from rd_addr for ADDX/SUBX)

  output logic [7:0] rs_data,
  output logic [7:0] rd_data
);

  logic [7:0] regs [8];  // R0-R7

  // write on clock edge
  always_ff @(posedge clk)
    if (enable) regs[wr_addr] <= data_in;

  // read combinationally
  assign rs_data = regs[rs_addr];
  assign rd_data = regs[rd_addr];

endmodule
