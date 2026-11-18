`timescale 1ns/1ps

module regfile (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        we,
    input  logic [4:0]  rs1_addr,
    input  logic [4:0]  rs2_addr,
    input  logic [4:0]  rd_addr,
    input  logic [31:0] rd_data,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);
    logic [31:0] regs [31:0];

    // Asynchronous read with x0 hardwired to zero and internal write-first bypass
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 :
                      ((we && (rd_addr == rs1_addr)) ? rd_data : regs[rs1_addr]);
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 :
                      ((we && (rd_addr == rs2_addr)) ? rd_data : regs[rs2_addr]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) regs[i] <= 32'd0;
        end else if (we && (rd_addr != 5'd0)) begin
            regs[rd_addr] <= rd_data;
        end
    end
endmodule
