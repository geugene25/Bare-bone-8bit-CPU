/*
 * Control Unit for simple 8-bit CPU.
*/

module control (input clk, reset, interrupt,
                input [7:0] datamem_data, datamem_address,  regfile_out1, regfile_out2, alu_out,


                output reg [3:0] alu_opcode,
                output reg [7:0] regfile_data, output [7:0] usermem_data,
                output reg [1:0] regfile_read1, regfile_read2, regfile_writereg,
                output reg [7:0] usermem_address, pc_jmpaddr,
                output reg rw, regfile_regwrite, pc_jump);
        /* Flags */
    //reg [1:0]  state;
reg [1:0] stage;
    reg [7:0] instruction_c;
reg [7:0] instruction;
reg [7:0] prevaddr;
    reg [7:0] umd;
    reg [1:0] next_state;
    reg [7:0] datamem_addresss;
    parameter SIZE = 3;
    parameter S0 = 3'b001, S1 = 3'b010, SIR = 3'b100;

    parameter state0 = 2'b00;
    parameter state1 = 2'b01;
    parameter state2 = 2'b10;
    parameter state3 = 2'b11;
    
  assign usermem_data=rw?umd:8'bz;

    reg is_onecyc, is_rts;
    always @(*) begin
      if (stage==2'b00) begin
        instruction_c<=datamem_data;
        is_onecyc <= (datamem_data[7:4] <= 4'h7);
        is_rts <= (datamem_data == 4'hb);
      end
    end
    always @ (stage or is_rts or interrupt or is_onecyc)
        begin : FSM_COMBO
        next_state = 3'b001;
        case(stage)
            S0 : if (is_onecyc == 0)
                next_state = S1;
                else
                next_state = S0;
            S1 : if (interrupt == 1 || (is_onecyc == 0 && is_rts))
                    next_state = SIR;
                    else
                    next_state = S0;
            SIR : next_state = S0;
            default : next_state = S0;
        endcase
    end
        always @(posedge clk)
        /* Check for reset*/
        begin : FSM_SEQ
        if (reset == 1)
        begin stage <= S0;
        end
        else begin
        stage <= next_state;
        end
        end
        always @(stage or reset)
         begin : OUTPUT_LOGIC
            if(reset == 1)begin
            {instruction, alu_opcode, regfile_data, umd, usermem_address} <= 8'b0;
            {regfile_read1, regfile_read2, regfile_writereg} <= 3'b0;
            {rw, regfile_regwrite, pc_jump} <= 1'b0;

            end else begin
            case(stage)
            S0: begin
                rw <= 0;
                regfile_regwrite <= 1;
                regfile_read1 <= instruction_c[3:2];
                regfile_read2 <= instruction_c[1:0];
                alu_opcode <= instruction_c[7:4];
                regfile_writereg <= instruction_c[1:0];
                regfile_data <= alu_out;

                end
             S1: case (instruction_c[7:4])
                                        4'h8 /* LD */:
                                        begin
                                                rw <= 0;
                                                regfile_writereg <= instruction[1:0];
                                                regfile_regwrite <= 1;
                                                regfile_data <= datamem_data;
                                        end
                                        4'h9 /* JMP */:
                                        begin
                                                rw <= 0;
                                                pc_jump <= 1;
                                                pc_jmpaddr <= datamem_data;
                                        end
                            4'ha /* CALL */:
                            begin
                                                rw <= 0;
                                prevaddr <= datamem_address + 1;
                                                pc_jump <= 1;
                                                pc_jmpaddr <= datamem_data;
                            end
                                        4'hc /* BEQ */:
                                        begin
                                                rw <= 0;
                                                regfile_regwrite <= 0;
                                                regfile_read1 <= instruction[3:2];
                                                regfile_read2 <= instruction[1:0];
                                                if(regfile_out1 == regfile_out2)
                                                begin
                                    prevaddr <= datamem_address + 1;
                                        pc_jump <= 1;
                                                        pc_jmpaddr <= datamem_data;
                                                end
                                        end
                            4'hd /* BNE */:
                            begin
                                                rw <= 0;
                                                regfile_regwrite <= 0;
                                                regfile_read1 <= instruction[3:2];
                                                regfile_read2 <= instruction[1:0];
                                                if(regfile_out1 != regfile_out2)
                                                begin
                                    prevaddr <= datamem_address + 1;
                                        pc_jump <= 1;
                                                        pc_jmpaddr <= datamem_data;
                                                end
                            end
                            4'he /* ST */:
                            begin
                                rw <= 1;
                                usermem_address <= datamem_data;
                                                regfile_read1 <= instruction[3:2];
                                umd <= regfile_out1;
                            end
                            4'hf /* LDUMEM */:
                            begin
                                                rw <= 0;
                                usermem_address <= datamem_data;
                                                regfile_writereg <= instruction[1:0];
                                                regfile_regwrite <= 1;
                                                regfile_data <= usermem_data;
                            end
                        endcase

               SIR: begin
                            prevaddr <= datamem_address;
                            pc_jump <= 1;
                            pc_jmpaddr <= 8'hfe;
                            end
endcase
end
end

/*always @ (posedge clk)
begin
if (datamem_address == 8'b00001001)
    datamem_addresss <= 8'b0;

end
*/

endmodule //control


module pc(input clk, reset, jump,
          input [7:0] jmpaddr,
          output reg[7:0] data);

always @(posedge clk) begin
if (reset == 1)
data <= 8'b0;
else if (reset == 0)
begin
if (jump == 1)
data <= jmpaddr;
else if (jump == 0)
data <= data + 1;
end
end
endmodule //pc
