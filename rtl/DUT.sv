// Top-level DUT
// Runs three programs sequentially, selected by prog_sel counter
// done: asserted when program writes to mem[192], cleared on start
// Memory writes blocked while start=1

module DUT (
  input  logic clk,
  input  logic start,
  output logic done
);

  // --- program start addresses ---
  parameter P1_START = 8'd0;
  parameter P2_START = 8'd85;
  parameter P3_START = 8'd170;

  // --- program selector: increments on each rising edge of start ---
  logic [1:0] prog_sel;
  logic       start_q;

  always_ff @(posedge clk) start_q <= start;

  always_ff @(posedge clk)
    if (start & ~start_q) prog_sel <= prog_sel + 1;

  // --- start address mux ---
  logic [7:0] start_addr;
  always_comb case (prog_sel)
    2'd0:    start_addr = P1_START;
    2'd1:    start_addr = P2_START;
    2'd2:    start_addr = P3_START;
    default: start_addr = P1_START;
  endcase

  // --- program counter ---
  logic [7:0] pc, next_pc;

  always_ff @(posedge clk)
    if (start) pc <= start_addr;
    else       pc <= next_pc;

  // --- instruction memory ---
  logic [8:0] instr;
  inst_mem im (.addr(pc), .instr);

  // --- flags (registered; cleared on start) ---
  logic carry,  carry_next;
  logic borrow, borrow_next;
  // logic zero,   zero_next;   // zero flag not used yet

  always_ff @(posedge clk) begin
    if (start) begin
      carry  <= 1'b0;
      borrow <= 1'b0;
      // zero   <= 1'b0;
    end else begin
      carry  <= carry_next;
      borrow <= borrow_next;
      // zero   <= zero_next;
    end
  end

  // --- register file ---
  logic [7:0] reg_data_in, rs_data, rd_data;
  logic       reg_enable;
  logic [2:0] rs_addr, rd_addr, wr_addr;

  reg_file rf (
    .clk,
    .enable  (reg_enable),
    .data_in (reg_data_in),
    .rs_addr,
    .rd_addr,
    .wr_addr,
    .rs_data,
    .rd_data
  );

  // --- data memory (writes blocked while start=1) ---
  logic [7:0] mem_addr, mem_data_in, mem_data_out;
  logic       mem_enable;

  dat_mem dm (
    .clk,
    .enable   (mem_enable & ~start),
    .addr     (mem_addr),
    .data_in  (mem_data_in),
    .data_out (mem_data_out)
  );

  // --- execute ---
  execute ex (
    .instr,
    .pc,
    .carry_in   (carry),
    .borrow_in  (borrow),
    // .zero_in    (zero),      // zero flag not used yet
    .rs_data,
    .rd_data,
    .reg_data_in,
    .reg_enable,
    .rs_addr,
    .rd_addr,
    .wr_addr,
    .mem_data_out,
    .mem_addr,
    .mem_data_in,
    .mem_enable,
    .next_pc,
    .carry_out  (carry_next),
    .borrow_out (borrow_next)
    // .zero_out   (zero_next)  // zero flag not used yet
  );

  // --- done: set when program writes to mem[192], cleared on start ---
  always_ff @(posedge clk)
    if (start)                                    done <= 1'b0;
    else if (mem_enable & (mem_addr == 8'd192))   done <= 1'b1;

endmodule
