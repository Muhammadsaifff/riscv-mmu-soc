// Small-I/O physical-design wrapper.
// APB is tied off for hardening; the complete APB/MMU implementation remains
// inside Top. The wrapper keeps debug ports internal so the GDS top-level does
// not become an impractically large 100+ pin interface.
module SoC_Hardened(
    input wire clk,
    input wire reset,
    output wire uart_tx,
    output wire [3:0] gpio
`ifdef USE_POWER_PINS
    ,inout wire vccd1
    ,inout wire vssd1
`endif
);

    wire [31:0] prdata;
    wire pready;
    wire [15:0] gpio_all;

    Top #(
        .IMEM_INIT_PATH("imem.dat"),
        .CLK_FREQ_HZ(100_000_000)
    ) u_top (
        .clk(clk),
        .reset(reset),
        .psel(1'b0),
        .penable(1'b0),
        .pwrite(1'b0),
        .paddr(32'b0),
        .pwdata(32'b0),
        .prdata(prdata),
        .pready(pready),
        .uart_tx_o(uart_tx),
        .gpio(gpio_all),

        .dbg_i_va(),
        .dbg_i_pa(),
        .dbg_d_va(),
        .dbg_d_pa(),
        .dbg_i_valid(),
        .dbg_d_valid(),
        .dbg_d_write(),
        .dbg_i_fault(),
        .dbg_d_fault(),
        .dbg_i_perm_fault(),
        .dbg_d_perm_fault(),
        .dbg_i_tlb_hit(),
        .dbg_d_tlb_hit(),
        .dbg_i_tlb_miss(),
        .dbg_d_tlb_miss(),
        .dbg_mmu_enable(),
        .dbg_uart_busy(),
        .dbg_d_write_commit(),
        .dbg_i_fault_sticky(),
        .dbg_d_fault_sticky(),
        .dbg_i_perm_sticky(),
        .dbg_d_perm_sticky()
`ifdef USE_POWER_PINS
        ,.vccd1(vccd1)
        ,.vssd1(vssd1)
`endif
    );

    assign gpio = gpio_all[3:0];

endmodule
