module fpga_top(
    input wire CLK100MHZ,
    input wire btn_reset,
    input wire [1:0] btn_mode,
    output wire [3:0] led,
    output wire uart_tx
);

    wire [31:0] prdata;
    wire pready;
    wire [15:0] gpio;

    wire uart_busy_dbg;
    wire i_fault_sticky;
    wire d_fault_sticky;
    wire i_perm_sticky;
    wire d_perm_sticky;

    reg psel;
    reg penable;
    reg pwrite;
    reg [31:0] paddr;
    reg [31:0] pwdata;

    reg [3:0] state;
    reg [1:0] requested_mode;
    reg [1:0] applied_mode;
    reg [7:0] report_char;
    reg [31:0] delay_count;
    reg fault_reported;

    localparam ST_IDLE    = 4'd0;
    localparam ST_CTRL    = 4'd1;
    localparam ST_PTE     = 4'd2;
    localparam ST_WAIT_TX = 4'd3;
    localparam ST_UART    = 4'd4;
    localparam ST_DELAY   = 4'd5;

    wire [4:0] selected_flags =
        (requested_mode == 2'b10) ? 5'b00000 :
        (requested_mode == 2'b11) ? 5'b00011 :
                                    5'b01111;

    wire [19:0] selected_ppn =
        (requested_mode == 2'b00) ? 20'h00000 :
        (requested_mode == 2'b01) ? 20'h00001 :
        (requested_mode == 2'b11) ? 20'h00001 :
                                    20'h00000;

    Top #(
        .IMEM_INIT_PATH("imem.dat"),
        .CLK_FREQ_HZ(100_000_000)
    ) soc (
        .clk(CLK100MHZ),
        .reset(btn_reset),

        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),

        .prdata(prdata),
        .pready(pready),

        .uart_tx_o(uart_tx),
        .gpio(gpio),

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
        .dbg_uart_busy(uart_busy_dbg),
        .dbg_d_write_commit(),
        .dbg_i_fault_sticky(i_fault_sticky),
        .dbg_d_fault_sticky(d_fault_sticky),
        .dbg_i_perm_sticky(i_perm_sticky),
        .dbg_d_perm_sticky(d_perm_sticky)
    );

    always @(*) begin
        psel = 1'b0;
        penable = 1'b0;
        pwrite = 1'b0;
        paddr = 32'h00000000;
        pwdata = 32'h00000000;

        case (state)

            ST_CTRL: begin
                psel = 1'b1;
                penable = 1'b1;
                pwrite = 1'b1;
                paddr = 32'h00000000;
                pwdata = 32'h00000003;
            end

            ST_PTE: begin
                psel = 1'b1;
                penable = 1'b1;
                pwrite = 1'b1;
                paddr = 32'h00000014;
                pwdata = {7'b0000000, selected_flags, selected_ppn};
            end

            ST_UART: begin
                psel = 1'b1;
                penable = 1'b1;
                pwrite = 1'b1;
                paddr = 32'h00000080;
                pwdata = {24'b0, report_char};
            end

            default: begin
                psel = 1'b0;
                penable = 1'b0;
                pwrite = 1'b0;
                paddr = 32'h00000000;
                pwdata = 32'h00000000;
            end

        endcase
    end

    always @(posedge CLK100MHZ or posedge btn_reset) begin

        if (btn_reset) begin
            state <= ST_IDLE;
            requested_mode <= 2'b00;
            applied_mode <= 2'b11;
            report_char <= 8'h30;
            delay_count <= 32'd0;
            fault_reported <= 1'b0;
        end

        else begin

            requested_mode <= btn_mode;

            case (state)

                ST_IDLE: begin
                    if (btn_mode != applied_mode) begin
                        applied_mode <= btn_mode;
                        report_char <= 8'h30 + btn_mode;
                        fault_reported <= 1'b0;
                        state <= ST_CTRL;
                    end
                end

                ST_CTRL: begin
                    state <= ST_PTE;
                end

                ST_PTE: begin
                    state <= ST_WAIT_TX;
                end

                ST_WAIT_TX: begin
                    if (!uart_busy_dbg)
                        state <= ST_UART;
                end

                ST_UART: begin
                    delay_count <= 32'd2_000_000;
                    state <= ST_DELAY;
                end

                ST_DELAY: begin

                    if (delay_count != 0) begin
                        delay_count <= delay_count - 1'b1;
                    end

                    else if (!fault_reported &&
                             (d_fault_sticky ||
                              d_perm_sticky ||
                              i_fault_sticky ||
                              i_perm_sticky)) begin

                        report_char <= 8'h46;
                        fault_reported <= 1'b1;
                        state <= ST_WAIT_TX;
                    end

                    else begin
                        state <= ST_IDLE;
                    end

                end

                default: begin
                    state <= ST_IDLE;
                end

            endcase
        end
    end

    assign led[0] = gpio[0];
    assign led[1] = gpio[4];
    assign led[2] = d_fault_sticky;
    assign led[3] = d_perm_sticky;

endmodule
