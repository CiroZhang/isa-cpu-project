// ================================================================================
// Type 1: [4-bit opcode | 3-bit Rd | 2-bit Rs]
// ================================================================================
// ADD     0000    Rd = Rd + Rs + carry                 sets carry  
// ADDX    0001    Rd = Rd + Rs{+4} + carry             sets carry  
// SUB     0010    Rd = Rd - Rs{+4} - borrow            sets borrow
// SUBX    0011    Rd = Rd - Rs - borrow                sets borrow
// MUL     0100    Rd = Rd * Rs 'b{8:0}
// MULC    0101    Rd = Rd * Rs 'b{16:8}  
// STR     0110    mem[Rs] = Rd              
// LD      0111    Rd = mem[Rs] 
// XOR     1000    Rd = Rd ^ Rs
// ================================================================================
// Type 2: [4-bit opcode | 3-bit Rd | 2-bit imm]      imm range: 0-3  (2-bit)
// ================================================================================
// SHIFT   1001    if imm[1]=0: Rd = Rd << (imm[0]+1)   shift left  by 1 or 2
//                 if imm[1]=1: Rd = Rd >> (imm[0]+1)   shift right by 1 or 2
// LDI     1010    Rd = imm                              
// ADDI    1011    Rd = Rd + imm 
// SUBI    1100    Rd = Rd - imm        
// ================================================================================
// Type 3: [4-bit opcode | 5-bit offset]
// ================================================================================
// BBS     1101    if borrow == 1: PC = PC + offset * 2        offset range -32..+30
// J       1110    PC = PC + offset * 2                        offset range -32..+30
// ================================================================================
// Type 4: [1111 | 3-bit Rd | 2-bit fun]
// ================================================================================
// NOT     00    Rd = Not(Rd)       
// COU     01    Rd = count(Rd)               
// ...     10    borrow = sign(Rd)
// DONE    11    Set Done             



module execute (
  input  logic [8:0] instr,
  input  logic [7:0] pc,
  input  logic       carry_in,
  input  logic       borrow_in,

  // register file ports
  input  logic [7:0] rs_data,
  input  logic [7:0] rd_data,
  output logic [7:0] reg_data_in,
  output logic       reg_enable,
  output logic [2:0] rs_addr,
  output logic [2:0] rd_addr,
  output logic [2:0] wr_addr,

  // data memory ports
  input  logic [7:0] mem_data_out,
  output logic [7:0] mem_addr,
  output logic [7:0] mem_data_in,
  output logic       mem_enable,

  // outputs
  output logic [7:0] next_pc,
  output logic       carry_out,
  output logic       borrow_out
);

  logic [3:0] opcode;
  logic [4:0] offset;
  logic [1:0] imm;

  logic [8:0]  add_sum;
  logic [8:0]  addi_sum;
  logic [8:0]  subi_diff;
  logic [8:0]  sub_diff;
  logic [15:0] product;
  logic [7:0]  xor_tmp;
  logic signed [7:0] branch_offset;

  assign opcode = instr[8:5];
  assign offset = instr[4:0];
  assign imm    = instr[1:0];

  assign rs_addr = (opcode == 4'b0001 || opcode == 4'b0010)
                 ? (instr[1:0] + 3'd4)
                 : {1'b0, instr[1:0]};

  assign rd_addr = instr[4:2];

  assign add_sum  = {1'b0, rd_data} + {1'b0, rs_data} + {8'b0, carry_in};
  assign sub_diff = {1'b0, rd_data} - {1'b0, rs_data} - {8'b0, borrow_in};
  assign product  = rd_data * rs_data;
  assign xor_tmp  = rd_data ^ rs_data;
  assign branch_offset = $signed({{2{offset[4]}}, offset, 1'b0});

  always_comb begin
    reg_data_in = 8'b0;
    reg_enable  = 1'b0;
    mem_enable  = 1'b0;
    mem_addr    = rs_data;
    mem_data_in = rd_data;
    wr_addr     = rd_addr;
    carry_out   = carry_in;
    borrow_out  = borrow_in;
    next_pc     = pc + 8'd1;

    case (opcode)
      // --- Type 1 ---
      4'b0000,
      4'b0001: begin // ADD / ADDX
        reg_enable  = 1'b1;
        reg_data_in = add_sum[7:0];
        carry_out   = add_sum[8];
      end

      4'b0010,
      4'b0011: begin // SUB / SUBX
        reg_enable  = 1'b1;
        reg_data_in = sub_diff[7:0];
        borrow_out  = sub_diff[8];
      end

      4'b0100: begin // MUL: Rd = (Rd * Rs)[7:0]
        reg_enable  = 1'b1;
        reg_data_in = product[7:0];
      end

      4'b0101: begin // MULC: Rd = (Rd * Rs)[15:8]
        reg_enable  = 1'b1;
        reg_data_in = product[15:8];
      end

      4'b0110: begin // STR: mem[Rs] = Rd
        mem_enable = 1'b1;
      end

      4'b0111: begin // LD: Rd = mem[Rs]
        reg_enable  = 1'b1;
        reg_data_in = mem_data_out;
      end

      4'b1000: begin // XOR: Rd = Rd ^ Rs
        reg_enable  = 1'b1;
        reg_data_in = xor_tmp;
      end

      // --- Type 2 ---
      4'b1001: begin // SHIFT
        reg_enable  = 1'b1;
        reg_data_in = (imm[1] == 1'b0)
                    ? (imm[0] ? (rd_data << 2) : (rd_data << 1))
                    : (imm[0] ? (rd_data >> 2) : (rd_data >> 1));
      end

      4'b1010: begin // LDI: Rd = imm (0-3)
        reg_enable  = 1'b1;
        reg_data_in = {6'b0, imm};
      end

      4'b1011: begin // ADDI: Rd = Rd + imm
        reg_enable  = 1'b1;
        addi_sum    = {1'b0, rd_data} + {7'b0, imm};
        reg_data_in = addi_sum[7:0];
        carry_out   = addi_sum[8];
      end

      4'b1100: begin // SUBI: Rd = Rd - imm
        reg_enable  = 1'b1;
        subi_diff    = {1'b0, rd_data} - {7'b0, imm};
        reg_data_in =  subi_diff[7:0];
        borrow_out   = subi_diff[8];
      end

      // --- Type 3 ---
      4'b1101: begin // BBS: branch if borrow set
        if (borrow_in) begin
          borrow_out = 1'b0;
          next_pc    = pc + branch_offset;
        end
      end

      4'b1110: begin // J: unconditional jump
        next_pc = pc + branch_offset;
      end

      // --- Type 4 ---
      4'b1111: begin
        case (instr[1:0])
          2'b00: begin // NOT: Rd = ~Rd
            reg_enable  = 1'b1;
            reg_data_in = ~rd_data;
          end

          2'b01: begin // COU: Rd = popcount(Rd)
            reg_enable  = 1'b1;
            reg_data_in = rd_data[0] + rd_data[1] + rd_data[2] + rd_data[3] +
                          rd_data[4] + rd_data[5] + rd_data[6] + rd_data[7];
          end

          2'b10: begin // SIGN: borrow = sign(Rd)
             borrow_out  = rd_data[7];
          end

          2'b11: begin // Set Done: write to mem[192]
            mem_enable  = 1'b1;
            mem_addr    = 8'd192;
            mem_data_in = 8'b0;
          end
        endcase
      end

      default: begin
      end
    endcase
  end

endmodule