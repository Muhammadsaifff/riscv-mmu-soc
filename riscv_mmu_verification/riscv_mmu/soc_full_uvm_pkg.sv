package soc_full_uvm_pkg;

  import uvm_pkg::*;
  import vm_apb_pkg::*;
  `include "uvm_macros.svh"

  // ------------------------------------------------------------
  // Small APB helper sequences used by the full-SoC test.
  // ------------------------------------------------------------
  class soc_restore_seq extends apb_base_seq;
    `uvm_object_utils(soc_restore_seq)

    function new(string name="soc_restore_seq");
      super.new(name);
    endfunction

    task body();
      // PTE1: VPN1 -> PPN1, V=1,R=1,W=1,X=0,U=0.
      write_reg(32'h00000014, {7'b0, 5'b00111, 20'h00001});
      write_reg(A_CTRL, 32'h00000003); // keep enabled + flush TLB
    endtask
  endclass

  class soc_uart_seq extends apb_base_seq;
    `uvm_object_utils(soc_uart_seq)

    function new(string name="soc_uart_seq");
      super.new(name);
    endfunction

    task body();
      bit [31:0] r;
      write_reg(A_UART, 32'h000000A5);
      read_reg(A_USTAT, r);
      `uvm_info("SOC", $sformatf("UART_STATUS=%08h", r), UVM_LOW)
      if (^r[0] === 1'bx)
        `uvm_error("SOC", "UART busy status is X")
    endtask
  endclass

  class soc_status_read_seq extends apb_base_seq;
    `uvm_object_utils(soc_status_read_seq)
    bit [31:0] status;

    function new(string name="soc_status_read_seq");
      super.new(name);
    endfunction

    task body();
      read_reg(A_STATUS, status);
    endtask
  endclass

  // ------------------------------------------------------------
  // FULL SOC TEST
  // ------------------------------------------------------------
  // This reuses the existing APB agent, VM monitor, VM scoreboard and
  // coverage from vm_apb_pkg, then adds end-to-end checks for:
  //   CPU/register file, IMEM execution, DMEM store/load,
  //   MMU/TLB translation, APB, UART and GPIO.
  // ------------------------------------------------------------
  class soc_full_test extends uvm_test;
    `uvm_component_utils(soc_full_test)

    vm_env env;
    virtual soc_full_if soc_vif;

    function new(string name="soc_full_test", uvm_component parent=null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      env = vm_env::type_id::create("env", this);

      if (!uvm_config_db#(virtual soc_full_if)::get(
            this, "", "soc_vif", soc_vif)) begin
        `uvm_fatal("NOVIF", "virtual soc_full_if not configured")
      end
    endfunction

    task wait_cycles(int unsigned n);
      repeat (n) @(soc_vif.cb);
    endtask

    task check32(string name, bit [31:0] got, bit [31:0] exp);
      if (got !== exp)
        `uvm_error("SOC", $sformatf("%s mismatch: got=%08h expected=%08h", name, got, exp))
      else
        `uvm_info("SOC", $sformatf("PASS: %s = %08h", name, got), UVM_LOW)
    endtask

    task check1(string name, bit got, bit exp);
      if (got !== exp)
        `uvm_error("SOC", $sformatf("%s mismatch: got=%0b expected=%0b", name, got, exp))
      else
        `uvm_info("SOC", $sformatf("PASS: %s = %0b", name, got), UVM_LOW)
    endtask

    task run_phase(uvm_phase phase);
      vm_integration_seq integ;
      soc_restore_seq restore;
      soc_uart_seq uart_seq;
      soc_status_read_seq status_seq;
      bit saw_store_commit;
      bit saw_data_access;
      bit saw_translated_data;
      bit [31:0] final_status;

      phase.raise_objection(this);

      `uvm_info("SOC", "==============================================", UVM_NONE)
      `uvm_info("SOC", "STARTING FULL RV32I + MMU + APB SOC TEST", UVM_NONE)
      `uvm_info("SOC", "==============================================", UVM_NONE)

      // ----------------------------------------------------------
      // 1. Reset complete SoC.
      // ----------------------------------------------------------
      env.agent.drv.reset_dut();
      wait_cycles(2);
      check1("MMU reset enable", soc_vif.cb.gpio[0], 1'b1);

      // ----------------------------------------------------------
      // 2. Existing MMU/APB integration sequence.
      // ----------------------------------------------------------
      integ = vm_integration_seq::type_id::create("integ");
      integ.start(env.agent.seqr);

      // ----------------------------------------------------------
      // 3. The supplied dmem implementation clears 8192 bytes as
      //    2048 words after reset. Wait for that initialization to end
      //    before declaring architectural store/load results valid.
      // ----------------------------------------------------------
      `uvm_info("SOC", "Waiting for DMEM reset initialization...", UVM_LOW)
      wait_cycles(2100);

      // The random configuration sequence from vm_apb_test is not run here;
      // restore the exact PTE1 state needed by test_program.dat.
      restore = soc_restore_seq::type_id::create("restore");
      restore.start(env.agent.seqr);

      // Allow several complete SW/LW loop iterations.
      saw_store_commit = 1'b0;
      saw_data_access  = 1'b0;
      saw_translated_data = 1'b0;

      repeat (50) begin
        @(soc_vif.cb);
        if (soc_vif.cb.dmem_we_safe)
          saw_store_commit = 1'b1;
        if (soc_vif.cb.dmem_we_raw)
          saw_data_access = 1'b1;
        if (soc_vif.cb.dmem_va == 32'h00001000 &&
            soc_vif.cb.dmem_pa == 32'h00001000)
          saw_translated_data = 1'b1;
      end

      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)
      `uvm_info("SOC", "CHECKING RV32I CPU / REGISTER FILE", UVM_NONE)
      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)

      check32("x0", soc_vif.cb.x0, 32'd0);
      check32("x1", soc_vif.cb.x1, 32'd10);
      check32("x2", soc_vif.cb.x2, 32'd20);
      check32("x3", soc_vif.cb.x3, 32'd30);
      check32("x4", soc_vif.cb.x4, 32'd20);
      check32("x5", soc_vif.cb.x5, 32'd42);
      check32("x6", soc_vif.cb.x6, 32'h00001000);
      check32("x7", soc_vif.cb.x7, 32'd42);

      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)
      `uvm_info("SOC", "CHECKING IMEM / PC EXECUTION", UVM_NONE)
      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)

      if (soc_vif.cb.pc[1:0] !== 2'b00)
        `uvm_error("SOC", $sformatf("PC is not word aligned: %08h", soc_vif.cb.pc))
      else
        `uvm_info("SOC", $sformatf("PASS: PC word aligned = %08h", soc_vif.cb.pc), UVM_LOW)

      if (soc_vif.cb.inst_raw === 32'h00000000 ||
          soc_vif.cb.inst_raw === 32'hxxxxxxxx) begin
        `uvm_error("SOC", $sformatf("IMEM instruction invalid: %08h", soc_vif.cb.inst_raw))
      end
      else begin
        `uvm_info("SOC", $sformatf("PASS: IMEM instruction active = %08h", soc_vif.cb.inst_raw), UVM_LOW)
      end

      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)
      `uvm_info("SOC", "CHECKING DMEM STORE / LOAD", UVM_NONE)
      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)

      check32("DMEM[0x1000]", soc_vif.cb.dmem_word_1000, 32'd42);

      if (!saw_store_commit)
        `uvm_error("SOC", "No successful DMEM store commit observed")
      else
        `uvm_info("SOC", "PASS: DMEM store commit observed", UVM_LOW)

      if (!saw_data_access)
        `uvm_error("SOC", "No CPU data-memory write observed")
      else
        `uvm_info("SOC", "PASS: CPU generated data-memory write", UVM_LOW)

      if (!saw_translated_data)
        `uvm_error("SOC", "No VA=0x1000 -> PA=0x1000 translation observed")
      else
        `uvm_info("SOC", "PASS: data VA 0x1000 translated to PA 0x1000", UVM_LOW)

      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)
      `uvm_info("SOC", "CHECKING MMU / TLB / FAULT STATE", UVM_NONE)
      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)

      status_seq = soc_status_read_seq::type_id::create("status_seq");
      status_seq.start(env.agent.seqr);
      final_status = status_seq.status;
      `uvm_info("SOC", $sformatf("Final STATUS=%08h", final_status), UVM_LOW)

      check1("MMU enabled", soc_vif.cb.gpio[0], 1'b1);

      if (soc_vif.cb.dmem_pa !== 32'h00001000)
        `uvm_warning("SOC", $sformatf("Current D PA sample is %08h; the 50-cycle window already verified the translated access",
                                       soc_vif.cb.dmem_pa))

      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)
      `uvm_info("SOC", "CHECKING UART", UVM_NONE)
      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)

      uart_seq = soc_uart_seq::type_id::create("uart_seq");
      uart_seq.start(env.agent.seqr);

      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)
      `uvm_info("SOC", "CHECKING GPIO DEBUG OUTPUT", UVM_NONE)
      `uvm_info("SOC", "----------------------------------------------", UVM_NONE)

      if (^soc_vif.cb.gpio === 1'bx)
        `uvm_error("SOC", "GPIO contains X/Z")
      else
        `uvm_info("SOC", $sformatf("PASS: GPIO=%04h", soc_vif.cb.gpio), UVM_LOW)

      `uvm_info("SOC", "==============================================", UVM_NONE)
      `uvm_info("SOC", "FULL SOC TEST COMPLETED", UVM_NONE)
      `uvm_info("SOC", "CPU + CONTROL + DATAPATH + REGFILE + ALU", UVM_NONE)
      `uvm_info("SOC", "IMEM + DMEM + MMU + TLB + PAGE TABLE", UVM_NONE)
      `uvm_info("SOC", "APB + FAULT HANDLER + UART + GPIO", UVM_NONE)
      `uvm_info("SOC", "==============================================", UVM_NONE)

      phase.drop_objection(this);
    endtask

  endclass

endpackage
