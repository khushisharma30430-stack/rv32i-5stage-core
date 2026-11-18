`timescale 1ns/1ps

module forwarding_unit (
    input  logic [4:0] id_ex_rs1,
    input  logic [4:0] id_ex_rs2,
    input  logic [4:0] ex_mem_rd,
    input  logic       ex_mem_regwrite,
    input  logic [4:0] mem_wb_rd,
    input  logic       mem_wb_regwrite,
    output logic [1:0] forwardA,
    output logic [1:0] forwardB
);
    always_comb begin
        // Operand A forwarding priority: EX/MEM > MEM/WB > Register File
        if (ex_mem_regwrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            forwardA = 2'b10;
        else if (mem_wb_regwrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            forwardA = 2'b01;
        else
            forwardA = 2'b00;

        // Operand B forwarding priority: EX/MEM > MEM/WB > Register File
        if (ex_mem_regwrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
            forwardB = 2'b10;
        else if (mem_wb_regwrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2))
            forwardB = 2'b01;
        else
            forwardB = 2'b00;
    end
endmodule
