// Instruction memory (ROM)
// 256 entries of 9-bit instructions
// Read-only, combinational output
module inst_mem (
  input  logic [7:0] addr,
  output logic [8:0] instr
);

  logic [8:0] mem [256];

  initial $readmemb("program.txt", mem);
  assign instr = mem[addr];

endmodule
