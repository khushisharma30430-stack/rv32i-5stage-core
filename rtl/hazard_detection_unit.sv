`timescale 1ns/1ps

module hazard_detection_unit (
    input  logic       id_ex_memread,
    input  logic [4:0] id_ex_rd,
    input  logic [4:0] if_id_rs1,
    input  logic [4:0] if_id_rs2,
    output logic       stall_pipeline
);
    // Detect Load-Use data hazard requiring 1-cycle pipeline bubble
    always_comb begin
        if (id_ex_memread && (id_ex_rd != 5'd0) &&
           ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
            stall_pipeline = 1'b1;
        end else begin
            stall_pipeline = 1'b0;
        end
    end
endmodule
