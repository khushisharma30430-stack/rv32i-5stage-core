`timescale 1ns/1ps

module rv32i_core_tb;
    logic        clk;
    logic        rst_n;
    logic [31:0] imem_addr, imem_rdata;
    logic        dmem_we, dmem_re;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;

    logic [31:0] imem [0:63];
    logic [31:0] dmem [0:63];

    rv32i_core dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_we    (dmem_we),
        .dmem_re    (dmem_re),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata)
    );

    assign imem_rdata = imem[imem_addr[7:2]];
    assign dmem_rdata = dmem[dmem_addr[7:2]];

    always_ff @(posedge clk) begin
        if (dmem_we) dmem[dmem_addr[7:2]] <= dmem_wdata;
    end

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/rv32i_trace.vcd");
        $dumpvars(0, rv32i_core_tb);

        for (int i = 0; i < 64; i++) begin
            imem[i] = 32'h0000_0013; // NOP
            dmem[i] = 32'd0;
        end
        dmem[0] = 32'd25; // Preload memory word 0 with 25

        // Machine Code Program testing EX-forwarding, MEM-forwarding, Load-Use Stall & Store:
        imem[0] = 32'h0050_0093; // addi x1, x0, 5        (x1 = 5)
        imem[1] = 32'h00A0_0113; // addi x2, x0, 10       (x2 = 10)
        imem[2] = 32'h0020_81B3; // add  x3, x1, x2       (EX/MEM forward x1,x2 -> x3 = 15)
        imem[3] = 32'h0000_2203; // lw   x4, 0(x0)        (Load 25 into x4)
        imem[4] = 32'h0041_82B3; // add  x5, x3, x4       (Load-Use Stall 1 cycle -> x5 = 40)
        imem[5] = 32'h0050_2223; // sw   x5, 4(x0)        (Store 40 into dmem[1])

        rst_n = 0;
        #20 rst_n = 1;

        #150;
        if (dmem[1] == 32'd40)
            $display(">>> TEST PASSED: RV32I Pipeline Forwarding & Stall Verified (dmem[1] = %0d) <<<", dmem[1]);
        else
            $display(">>> TEST FAILED: Expected 40, got %0d <<<", dmem[1]);

        $finish;
    end
endmodule
