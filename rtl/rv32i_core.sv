`timescale 1ns/1ps

module rv32i_core (
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,
    output logic        dmem_we,
    output logic        dmem_re,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata
);
    // Pipeline Registers
    logic [31:0] pc, pc_next;
    logic [31:0] if_id_pc, if_id_instr;

    logic [31:0] id_ex_pc, id_ex_rs1_data, id_ex_rs2_data, id_ex_imm;
    logic [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;
    logic [3:0]  id_ex_alu_ctrl;
    logic        id_ex_alusrc, id_ex_memread, id_ex_memwrite, id_ex_regwrite, id_ex_memtoreg, id_ex_branch;

    logic [31:0] ex_mem_alu_result, ex_mem_rs2_data, ex_mem_branch_target;
    logic [4:0]  ex_mem_rd;
    logic        ex_mem_zero, ex_mem_memread, ex_mem_memwrite, ex_mem_regwrite, ex_mem_memtoreg, ex_mem_branch;

    logic [31:0] mem_wb_alu_result, mem_wb_mem_data;
    logic [4:0]  mem_wb_rd;
    logic        mem_wb_regwrite, mem_wb_memtoreg;

    // Control & Hazard Signals
    logic        stall_pipeline, branch_taken;
    logic [1:0]  forwardA, forwardB;
    logic [31:0] wb_data;

    // ==================== 1. IF STAGE ====================
    assign branch_taken = ex_mem_branch && ex_mem_zero;
    assign pc_next      = branch_taken ? ex_mem_branch_target : (pc + 32'd4);
    assign imem_addr    = pc;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc          <= 32'd0;
            if_id_pc    <= 32'd0;
            if_id_instr <= 32'h0000_0013; // NOP (addi x0, x0, 0)
        end else if (branch_taken) begin
            pc          <= pc_next;
            if_id_pc    <= 32'd0;
            if_id_instr <= 32'h0000_0013; // Flush on taken branch
        end else if (!stall_pipeline) begin
            pc          <= pc_next;
            if_id_pc    <= pc;
            if_id_instr <= imem_rdata;
        end
    end

    // ==================== 2. ID STAGE ====================
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [31:0] rs1_val, rs2_val, imm_ext;

    assign opcode   = if_id_instr[6:0];
    assign rd_addr  = if_id_instr[11:7];
    assign funct3   = if_id_instr[14:12];
    assign rs1_addr = if_id_instr[19:15];
    assign rs2_addr = if_id_instr[24:20];
    assign funct7   = if_id_instr[31:25];

    // Immediate Generator
    always_comb begin
        case (opcode)
            7'b0010011, 7'b0000011: // I-Type (ADDI, LW)
                imm_ext = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
            7'b0100011: // S-Type (SW)
                imm_ext = {{20{if_id_instr[31]}}, if_id_instr[31:25], if_id_instr[11:7]};
            7'b1100011: // B-Type (BEQ)
                imm_ext = {{19{if_id_instr[31]}}, if_id_instr[31], if_id_instr[7], if_id_instr[30:25], if_id_instr[11:8], 1'b0};
            default:
                imm_ext = 32'd0;
        endcase
    end

    regfile u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .we       (mem_wb_regwrite),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (mem_wb_rd),
        .rd_data  (wb_data),
        .rs1_data (rs1_val),
        .rs2_data (rs2_val)
    );

    hazard_detection_unit u_hazard (
        .id_ex_memread  (id_ex_memread),
        .id_ex_rd       (id_ex_rd),
        .if_id_rs1      (rs1_addr),
        .if_id_rs2      (rs2_addr),
        .stall_pipeline (stall_pipeline)
    );

    // Control Unit & ID/EX Pipeline Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || stall_pipeline || branch_taken) begin
            id_ex_pc       <= 32'd0;
            id_ex_rs1_data <= 32'd0;
            id_ex_rs2_data <= 32'd0;
            id_ex_imm      <= 32'd0;
            id_ex_rs1      <= 5'd0;
            id_ex_rs2      <= 5'd0;
            id_ex_rd       <= 5'd0;
            id_ex_alu_ctrl <= 4'd0;
            id_ex_alusrc   <= 1'b0;
            id_ex_memread  <= 1'b0;
            id_ex_memwrite <= 1'b0;
            id_ex_regwrite <= 1'b0;
            id_ex_memtoreg <= 1'b0;
            id_ex_branch   <= 1'b0;
        end else begin
            id_ex_pc       <= if_id_pc;
            id_ex_rs1_data <= rs1_val;
            id_ex_rs2_data <= rs2_val;
            id_ex_imm      <= imm_ext;
            id_ex_rs1      <= rs1_addr;
            id_ex_rs2      <= rs2_addr;
            id_ex_rd       <= rd_addr;

            case (opcode)
                7'b0110011: begin // R-type
                    id_ex_alusrc   <= 1'b0;
                    id_ex_memread  <= 1'b0;
                    id_ex_memwrite <= 1'b0;
                    id_ex_regwrite <= 1'b1;
                    id_ex_memtoreg <= 1'b0;
                    id_ex_branch   <= 1'b0;
                    if (funct3 == 3'b000 && funct7 == 7'b0100000) id_ex_alu_ctrl <= 4'b0001; // SUB
                    else if (funct3 == 3'b111) id_ex_alu_ctrl <= 4'b0010; // AND
                    else if (funct3 == 3'b110) id_ex_alu_ctrl <= 4'b0011; // OR
                    else if (funct3 == 3'b100) id_ex_alu_ctrl <= 4'b0100; // XOR
                    else id_ex_alu_ctrl <= 4'b0000; // ADD
                end
                7'b0010011: begin // I-type ALU (ADDI)
                    id_ex_alusrc   <= 1'b1;
                    id_ex_memread  <= 1'b0;
                    id_ex_memwrite <= 1'b0;
                    id_ex_regwrite <= 1'b1;
                    id_ex_memtoreg <= 1'b0;
                    id_ex_branch   <= 1'b0;
                    id_ex_alu_ctrl <= 4'b0000;
                end
                7'b0000011: begin // LW
                    id_ex_alusrc   <= 1'b1;
                    id_ex_memread  <= 1'b1;
                    id_ex_memwrite <= 1'b0;
                    id_ex_regwrite <= 1'b1;
                    id_ex_memtoreg <= 1'b1;
                    id_ex_branch   <= 1'b0;
                    id_ex_alu_ctrl <= 4'b0000;
                end
                7'b0100011: begin // SW
                    id_ex_alusrc   <= 1'b1;
                    id_ex_memread  <= 1'b0;
                    id_ex_memwrite <= 1'b1;
                    id_ex_regwrite <= 1'b0;
                    id_ex_memtoreg <= 1'b0;
                    id_ex_branch   <= 1'b0;
                    id_ex_alu_ctrl <= 4'b0000;
                end
                7'b1100011: begin // BEQ
                    id_ex_alusrc   <= 1'b0;
                    id_ex_memread  <= 1'b0;
                    id_ex_memwrite <= 1'b0;
                    id_ex_regwrite <= 1'b0;
                    id_ex_memtoreg <= 1'b0;
                    id_ex_branch   <= 1'b1;
                    id_ex_alu_ctrl <= 4'b0001; // SUB to check zero
                end
                default: begin
                    id_ex_alusrc   <= 1'b0;
                    id_ex_memread  <= 1'b0;
                    id_ex_memwrite <= 1'b0;
                    id_ex_regwrite <= 1'b0;
                    id_ex_memtoreg <= 1'b0;
                    id_ex_branch   <= 1'b0;
                    id_ex_alu_ctrl <= 4'b0000;
                end
            endcase
        end
    end

    // ==================== 3. EX STAGE ====================
    logic [31:0] alu_in_a, alu_in_b_fwd, alu_in_b, alu_out;
    logic        alu_zero;

    forwarding_unit u_forward (
        .id_ex_rs1       (id_ex_rs1),
        .id_ex_rs2       (id_ex_rs2),
        .ex_mem_rd       (ex_mem_rd),
        .ex_mem_regwrite (ex_mem_regwrite),
        .mem_wb_rd       (mem_wb_rd),
        .mem_wb_regwrite (mem_wb_regwrite),
        .forwardA        (forwardA),
        .forwardB        (forwardB)
    );

    always_comb begin
        case (forwardA)
            2'b10:   alu_in_a = ex_mem_alu_result;
            2'b01:   alu_in_a = wb_data;
            default: alu_in_a = id_ex_rs1_data;
        endcase

        case (forwardB)
            2'b10:   alu_in_b_fwd = ex_mem_alu_result;
            2'b01:   alu_in_b_fwd = wb_data;
            default: alu_in_b_fwd = id_ex_rs2_data;
        endcase
    end

    assign alu_in_b = id_ex_alusrc ? id_ex_imm : alu_in_b_fwd;

    alu u_alu (
        .a        (alu_in_a),
        .b        (alu_in_b),
        .alu_ctrl (id_ex_alu_ctrl),
        .result   (alu_out),
        .zero     (alu_zero)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || branch_taken) begin
            ex_mem_alu_result    <= 32'd0;
            ex_mem_rs2_data      <= 32'd0;
            ex_mem_branch_target <= 32'd0;
            ex_mem_rd            <= 5'd0;
            ex_mem_zero          <= 1'b0;
            ex_mem_memread       <= 1'b0;
            ex_mem_memwrite      <= 1'b0;
            ex_mem_regwrite      <= 1'b0;
            ex_mem_memtoreg      <= 1'b0;
            ex_mem_branch        <= 1'b0;
        end else begin
            ex_mem_alu_result    <= alu_out;
            ex_mem_rs2_data      <= alu_in_b_fwd;
            ex_mem_branch_target <= id_ex_pc + id_ex_imm;
            ex_mem_rd            <= id_ex_rd;
            ex_mem_zero          <= alu_zero;
            ex_mem_memread       <= id_ex_memread;
            ex_mem_memwrite      <= id_ex_memwrite;
            ex_mem_regwrite      <= id_ex_regwrite;
            ex_mem_memtoreg      <= id_ex_memtoreg;
            ex_mem_branch        <= id_ex_branch;
        end
    end

    // ==================== 4. MEM STAGE ====================
    assign dmem_we    = ex_mem_memwrite;
    assign dmem_re    = ex_mem_memread;
    assign dmem_addr  = ex_mem_alu_result;
    assign dmem_wdata = ex_mem_rs2_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_alu_result <= 32'd0;
            mem_wb_mem_data   <= 32'd0;
            mem_wb_rd         <= 5'd0;
            mem_wb_regwrite   <= 1'b0;
            mem_wb_memtoreg   <= 1'b0;
        end else begin
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data   <= dmem_rdata;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_regwrite   <= ex_mem_regwrite;
            mem_wb_memtoreg   <= ex_mem_memtoreg;
        end
    end

    // ==================== 5. WB STAGE ====================
    assign wb_data = mem_wb_memtoreg ? mem_wb_mem_data : mem_wb_alu_result;

endmodule
