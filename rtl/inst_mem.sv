// Instruction memory (ROM)
// 256 entries of 9-bit instructions
// Read-only, combinational output
module inst_mem (
  input  logic [8:0] addr,
  output logic [8:0] instr
);

  logic [8:0] mem [512];

  initial $readmemb("program.txt", mem);
  assign instr = mem[addr];

endmodule
