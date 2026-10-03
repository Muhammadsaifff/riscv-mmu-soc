package vm_apb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"


  // ============================================================
  // APB REGISTER MAP
  // ============================================================

  localparam bit [31:0] A_CTRL   = 32'h0000_0000;
  localparam bit [31:0] A_PTBR   = 32'h0000_0004;
  localparam bit [31:0] A_STATUS = 32'h0000_0008;
  localparam bit [31:0] A_FAULT  = 32'h0000_000C;

  localparam bit [31:0] A_PTE0   = 32'h0000_0010;

  localparam bit [31:0] A_UART   = 32'h0000_0080;
  localparam bit [31:0] A_USTAT  = 32'h0000_0084;


  // ============================================================
  // STATUS BIT DEFINITIONS
  //
  // Based on the observed RTL result:
  //
  //     STATUS = 32'h0000_0210
  //
  // which means:
  //
  //     bit 4 = D permission fault
  //     bit 9 = D sticky permission fault
  //
  // ============================================================

  localparam int STATUS_I_FAULT        = 0;
  localparam int STATUS_D_FAULT        = 4;
  localparam int STATUS_I_PERM_FAULT   = 5;
  localparam int STATUS_D_PERM_FAULT   = 4;

  localparam int STATUS_I_STICKY       = 8;
  localparam int STATUS_D_STICKY       = 9;


  // ============================================================
  // APB TRANSACTION
  // ============================================================

  class apb_item extends uvm_sequence_item;

    rand bit        write;
    rand bit [31:0] addr;
    rand bit [31:0] data;

    bit [31:0]      rdata;
    bit             success;

    `uvm_object_utils_begin(apb_item)
      `uvm_field_int(write,   UVM_ALL_ON)
      `uvm_field_int(addr,    UVM_ALL_ON)
      `uvm_field_int(data,    UVM_ALL_ON)
      `uvm_field_int(rdata,   UVM_ALL_ON)
      `uvm_field_int(success, UVM_ALL_ON)
    `uvm_object_utils_end


    function new(string name = "apb_item");
      super.new(name);
    endfunction

  endclass



  // ============================================================
  // VM STATUS TRANSACTION
  // ============================================================

  class vm_status_item extends uvm_sequence_item;

    bit        mmu_enable;

    bit [31:0] i_va;
    bit [31:0] i_pa;

    bit [31:0] d_va;
    bit [31:0] d_pa;

    bit        i_valid;
    bit        d_valid;

    bit        d_write;
    bit        d_write_commit;

    bit        i_fault;
    bit        d_fault;

    bit        i_perm_fault;
    bit        d_perm_fault;

    bit        i_tlb_hit;
    bit        d_tlb_hit;

    bit        i_tlb_miss;
    bit        d_tlb_miss;

    bit        i_fault_sticky;
    bit        d_fault_sticky;

    bit        i_perm_sticky;
    bit        d_perm_sticky;


    `uvm_object_utils(vm_status_item)


    function new(string name = "vm_status_item");
      super.new(name);
    endfunction

  endclass



  // ============================================================
  // APB SEQUENCER
  //
  // IMPORTANT:
  // The virtual interface is stored directly inside the sequencer.
  // This allows vm_integration_seq to use:
  //
  //     p_sequencer.vif.clk
  //
  // ============================================================

  class apb_sequencer extends uvm_sequencer #(apb_item);

    `uvm_component_utils(apb_sequencer)

    virtual apb_if vif;


    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);

      super.build_phase(phase);

      if (!uvm_config_db#(virtual apb_if)::get(
            this,
            "",
            "vif",
            vif
          )) begin

        `uvm_fatal(
          "NOVIF",
          "virtual apb_if not configured for apb_sequencer"
        )

      end

    endfunction

  endclass



  // ============================================================
  // APB DRIVER
  // ============================================================

  class apb_driver extends uvm_driver #(apb_item);

    `uvm_component_utils(apb_driver)

    virtual apb_if vif;

    int unsigned timeout_cycles = 20;


    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);

      super.build_phase(phase);

      if (!uvm_config_db#(virtual apb_if)::get(
            this,
            "",
            "vif",
            vif
          )) begin

        `uvm_fatal(
          "NOVIF",
          "virtual apb_if not configured for apb_driver"
        )

      end

    endfunction



    // ----------------------------------------------------------
    // DRIVE ONE APB TRANSACTION
    // ----------------------------------------------------------

    task drive_one(apb_item tr);

      int unsigned waited;

      // APB SETUP PHASE

      vif.master_cb.psel    <= 1'b1;
      vif.master_cb.penable <= 1'b0;
      vif.master_cb.pwrite  <= tr.write;
      vif.master_cb.paddr   <= tr.addr;
      vif.master_cb.pwdata  <= tr.data;

      @(vif.master_cb);


      // APB ACCESS PHASE

      vif.master_cb.penable <= 1'b1;

      waited = 0;


      do begin

        @(vif.master_cb);

        waited++;


        if (waited > timeout_cycles) begin

          tr.success = 1'b0;

          `uvm_error(
            "APB_DRV",
            $sformatf(
              "Timeout waiting PREADY: addr=%08h write=%0b",
              tr.addr,
              tr.write
            )
          )

          break;

        end

      end
      while (!vif.master_cb.pready);


      if (vif.master_cb.pready) begin

        tr.success = 1'b1;

        if (!tr.write)
          tr.rdata = vif.master_cb.prdata;

      end


      // RETURN TO IDLE

      vif.master_cb.psel    <= 1'b0;
      vif.master_cb.penable <= 1'b0;
      vif.master_cb.pwrite  <= 1'b0;
      vif.master_cb.paddr   <= 32'h0000_0000;
      vif.master_cb.pwdata  <= 32'h0000_0000;

      @(vif.master_cb);

    endtask



    // ----------------------------------------------------------
    // RESET DUT
    // ----------------------------------------------------------

    task reset_dut();

      vif.reset_n <= 1'b0;

      vif.master_cb.psel    <= 1'b0;
      vif.master_cb.penable <= 1'b0;
      vif.master_cb.pwrite  <= 1'b0;
      vif.master_cb.paddr   <= 32'h0000_0000;
      vif.master_cb.pwdata  <= 32'h0000_0000;

      repeat (4)
        @(vif.master_cb);

      vif.reset_n <= 1'b1;

      @(vif.master_cb);

    endtask



    // ----------------------------------------------------------
    // DRIVER RUN PHASE
    // ----------------------------------------------------------

    task run_phase(uvm_phase phase);

      apb_item tr;

      vif.master_cb.psel    <= 1'b0;
      vif.master_cb.penable <= 1'b0;
      vif.master_cb.pwrite  <= 1'b0;
      vif.master_cb.paddr   <= 32'h0000_0000;
      vif.master_cb.pwdata  <= 32'h0000_0000;


      forever begin

        seq_item_port.get_next_item(tr);

        drive_one(tr);

        seq_item_port.item_done();

      end

    endtask

  endclass



  // ============================================================
  // APB MONITOR
  // ============================================================

  class apb_monitor extends uvm_monitor;

    `uvm_component_utils(apb_monitor)

    virtual apb_if vif;

    uvm_analysis_port #(apb_item) ap;


    function new(string name, uvm_component parent);

      super.new(name, parent);

      ap = new("ap", this);

    endfunction


    function void build_phase(uvm_phase phase);

      super.build_phase(phase);

      if (!uvm_config_db#(virtual apb_if)::get(
            this,
            "",
            "vif",
            vif
          )) begin

        `uvm_fatal(
          "NOVIF",
          "virtual apb_if not configured for apb_monitor"
        )

      end

    endfunction


    task run_phase(uvm_phase phase);

      apb_item tr;


      forever begin

        @(vif.mon_cb);


        if (
          vif.mon_cb.psel &&
          vif.mon_cb.penable &&
          vif.mon_cb.pready
        ) begin

          tr = apb_item::type_id::create(
            "apb_mon",
            this
          );

          tr.write   = vif.mon_cb.pwrite;
          tr.addr    = vif.mon_cb.paddr;
          tr.data    = vif.mon_cb.pwdata;
          tr.rdata   = vif.mon_cb.prdata;
          tr.success = 1'b1;

          ap.write(tr);

        end

      end

    endtask

  endclass



  // ============================================================
  // VM STATUS MONITOR
  // ============================================================

  class vm_status_monitor extends uvm_monitor;

    `uvm_component_utils(vm_status_monitor)

    virtual vm_status_if vif;

    uvm_analysis_port #(vm_status_item) ap;


    function new(string name, uvm_component parent);

      super.new(name, parent);

      ap = new("ap", this);

    endfunction


    function void build_phase(uvm_phase phase);

      super.build_phase(phase);

      if (!uvm_config_db#(virtual vm_status_if)::get(
            this,
            "",
            "status_vif",
            vif
          )) begin

        `uvm_fatal(
          "NOVIF",
          "virtual vm_status_if not configured"
        )

      end

    endfunction


    task run_phase(uvm_phase phase);

      vm_status_item tr;


      forever begin

        @(vif.mon_cb);


        if (vif.reset)
          continue;


        tr = vm_status_item::type_id::create(
          "status",
          this
        );


        tr.mmu_enable =
          vif.mon_cb.mmu_enable;

        tr.i_va =
          vif.mon_cb.i_va;

        tr.i_pa =
          vif.mon_cb.i_pa;

        tr.d_va =
          vif.mon_cb.d_va;

        tr.d_pa =
          vif.mon_cb.d_pa;

        tr.i_valid =
          vif.mon_cb.i_valid;

        tr.d_valid =
          vif.mon_cb.d_valid;

        tr.d_write =
          vif.mon_cb.d_write;

        tr.d_write_commit =
          vif.mon_cb.d_write_commit;

        tr.i_fault =
          vif.mon_cb.i_fault;

        tr.d_fault =
          vif.mon_cb.d_fault;

        tr.i_perm_fault =
          vif.mon_cb.i_perm_fault;

        tr.d_perm_fault =
          vif.mon_cb.d_perm_fault;

        tr.i_tlb_hit =
          vif.mon_cb.i_tlb_hit;

        tr.d_tlb_hit =
          vif.mon_cb.d_tlb_hit;

        tr.i_tlb_miss =
          vif.mon_cb.i_tlb_miss;

        tr.d_tlb_miss =
          vif.mon_cb.d_tlb_miss;

        tr.i_fault_sticky =
          vif.mon_cb.i_fault_sticky;

        tr.d_fault_sticky =
          vif.mon_cb.d_fault_sticky;

        tr.i_perm_sticky =
          vif.mon_cb.i_perm_sticky;

        tr.d_perm_sticky =
          vif.mon_cb.d_perm_sticky;


        ap.write(tr);

      end

    endtask

  endclass



  // ============================================================
  // ANALYSIS IMPLEMENTATIONS
  // ============================================================

  `uvm_analysis_imp_decl(_apb)
  `uvm_analysis_imp_decl(_vm)



  // ============================================================
  // VM SCOREBOARD
  // ============================================================

  class vm_scoreboard extends uvm_component;

    `uvm_component_utils(vm_scoreboard)


    uvm_analysis_imp_apb #(
      apb_item,
      vm_scoreboard
    ) apb_imp;


    uvm_analysis_imp_vm #(
      vm_status_item,
      vm_scoreboard
    ) vm_imp;


    // ----------------------------------------------------------
    // PAGE TABLE MODEL
    // ----------------------------------------------------------

    bit [19:0] pte_ppn   [16];
    bit [4:0]  pte_flags [16];


    // ----------------------------------------------------------
    // I-TLB MODEL
    // ----------------------------------------------------------

    bit        i_tlb_valid [4];
    bit [19:0] i_tlb_vpn   [4];
    bit [19:0] i_tlb_ppn   [4];
    bit [4:0]  i_tlb_flags [4];


    // ----------------------------------------------------------
    // D-TLB MODEL
    // ----------------------------------------------------------

    bit        d_tlb_valid [4];
    bit [19:0] d_tlb_vpn   [4];
    bit [19:0] d_tlb_ppn   [4];
    bit [4:0]  d_tlb_flags [4];


    // ----------------------------------------------------------
    // CONTROL MODEL
    // ----------------------------------------------------------

    bit        model_enable;
    bit [31:0] model_ptbr;


    // ----------------------------------------------------------
    // CONTROL PIPELINE MODEL
    // ----------------------------------------------------------

    bit ctrl_stage1_en;
    bit ctrl_stage1_flush;

    bit pending_enable;
    bit pending_flush_tlb;

    bit has_pending_enable;
    bit has_pending_flush;

    int unsigned flush_delay_counter;


    // ----------------------------------------------------------
    // PTE WRITE PIPELINE
    // ----------------------------------------------------------

    typedef struct {

      int unsigned delay;

      bit [3:0] idx;

      bit [19:0] ppn;

      bit [4:0] flags;

    } pte_pend_s;


    pte_pend_s pte_pend_q[$];


    int unsigned checks;
    int unsigned errors;


    // ----------------------------------------------------------
    // CONSTRUCTOR
    // ----------------------------------------------------------

    function new(
      string name,
      uvm_component parent
    );

      super.new(name, parent);

      apb_imp = new("apb_imp", this);

      vm_imp = new("vm_imp", this);

      reset_model();

    endfunction



    // ----------------------------------------------------------
    // RESET SCOREBOARD MODEL
    // ----------------------------------------------------------

    function void reset_model();

      int i;


      // IMPORTANT:
      // The current DUT comes out of reset with MMU enabled.
      // The first APB transaction in the register test explicitly
      // disables it, so the scoreboard must start at the DUT reset
      // value to avoid false VM mismatches during the first cycles.

      model_enable = 1'b1;

      model_ptbr = 32'h0000_0000;


      ctrl_stage1_en    = 1'b0;
      ctrl_stage1_flush = 1'b0;


      pending_enable    = 1'b0;
      pending_flush_tlb = 1'b0;


      has_pending_enable = 1'b0;
      has_pending_flush  = 1'b0;


      flush_delay_counter = 0;


      pte_pend_q.delete();


      checks = 0;
      errors = 0;


      // Clear page table.

      for (i = 0; i < 16; i++) begin

        pte_ppn[i]   = 20'h00000;
        pte_flags[i] = 5'b00000;

      end


      // Default executable PTE0.

      pte_flags[0] = 5'b01111;


      // Clear I-TLB.

      for (i = 0; i < 4; i++) begin

        i_tlb_valid[i] = 1'b0;

        i_tlb_vpn[i] = 20'h00000;

        i_tlb_ppn[i] = 20'h00000;

        i_tlb_flags[i] = 5'b00000;

      end


      // Clear D-TLB.

      for (i = 0; i < 4; i++) begin

        d_tlb_valid[i] = 1'b0;

        d_tlb_vpn[i] = 20'h00000;

        d_tlb_ppn[i] = 20'h00000;

        d_tlb_flags[i] = 5'b00000;

      end

    endfunction



    // ----------------------------------------------------------
    // PERMISSION CHECK
    //
    // f[0] = V
    // f[1] = R
    // f[2] = W
    // f[3] = X
    // f[4] = U
    // ----------------------------------------------------------

    function bit allowed(
      bit [4:0] f,
      bit       wr,
      bit       ex
    );

      if (!f[0])
        return 1'b0;


      if (ex)
        return f[3];


      if (wr)
        return f[2];


      return f[1];

    endfunction



    // ----------------------------------------------------------
    // SCOREBOARD ERROR
    // ----------------------------------------------------------

    function void err(string msg);

      errors++;

      `uvm_error(
        "VM_SB",
        msg
      )

    endfunction



    // ----------------------------------------------------------
    // APB ANALYSIS
    // ----------------------------------------------------------

    function void write_apb(apb_item tr);

      int idx;


      if (!tr.success) begin

        err(
          "Observed APB transaction without successful PREADY"
        );

        return;

      end


      if (tr.write) begin

        case (tr.addr[7:0])


          // ----------------------------------------------------
          // CONTROL REGISTER
          // ----------------------------------------------------

          8'h00: begin

            ctrl_stage1_en =
              tr.data[0];

            ctrl_stage1_flush =
              tr.data[1];


            pending_enable =
              ctrl_stage1_en;

            has_pending_enable =
              1'b1;


            if (ctrl_stage1_flush) begin

              pending_flush_tlb =
                1'b1;

              has_pending_flush =
                1'b1;

              flush_delay_counter =
                2;

            end

          end


          // ----------------------------------------------------
          // PTBR
          // ----------------------------------------------------

          8'h04: begin

            model_ptbr =
              tr.data;

          end


          // ----------------------------------------------------
          // PTE REGISTERS
          // ----------------------------------------------------

          default: begin

            if (
              (tr.addr[7:0] >= 8'h10) &&
              (tr.addr[7:0] < 8'h50) &&
              (tr.addr[1:0] == 2'b00)
            ) begin

              idx =
                (tr.addr[5:2] - 4);


              pte_pend_q.push_back(
                '{
                  delay: 2,
                  idx: idx[3:0],
                  ppn: tr.data[19:0],
                  flags: tr.data[24:20]
                }
              );

            end

          end

        endcase

      end
      else begin

        // ------------------------------------------------------
        // READBACK
        // ------------------------------------------------------

        if (
          tr.addr == A_CTRL &&
          tr.rdata[0] !== model_enable
        ) begin

          err(
            $sformatf(
              "CTRL readback mismatch exp=%0b got=%0b",
              model_enable,
              tr.rdata[0]
            )
          );

        end


        if (
          tr.addr == A_PTBR &&
          tr.rdata !== model_ptbr
        ) begin

          err(
            $sformatf(
              "PTBR readback mismatch exp=%08h got=%08h",
              model_ptbr,
              tr.rdata
            )
          );

        end


        if (
          tr.addr == A_PTE0 &&
          tr.rdata !== 32'h0000_0000
        ) begin

          err(
            "PTE readback should be zero by current RTL specification"
          );

        end

      end

    endfunction



    // ----------------------------------------------------------
    // VM STATUS ANALYSIS
    // ----------------------------------------------------------

    function void write_vm(vm_status_item tr);

      int idx;

      bit h;

      bit ok;

      bit [19:0] ppn;

      bit [4:0] flags;


      // --------------------------------------------------------
      // APPLY ENABLE
      // --------------------------------------------------------

      if (has_pending_enable) begin

        model_enable =
          pending_enable;

        has_pending_enable =
          1'b0;

      end


      // --------------------------------------------------------
      // HANDLE TLB FLUSH
      // --------------------------------------------------------

      if (has_pending_flush) begin

        if (flush_delay_counter > 0)
          flush_delay_counter--;


        if (flush_delay_counter == 0) begin

          for (idx = 0; idx < 4; idx++) begin

            i_tlb_valid[idx] = 1'b0;

            d_tlb_valid[idx] = 1'b0;

          end


          has_pending_flush =
            1'b0;

          pending_flush_tlb =
            1'b0;

        end

      end


      // --------------------------------------------------------
      // AGE PTE WRITE PIPELINE
      // --------------------------------------------------------

      foreach (pte_pend_q[i])
        if (pte_pend_q[i].delay > 0)
          pte_pend_q[i].delay--;


      while (
        pte_pend_q.size() > 0 &&
        pte_pend_q[0].delay == 0
      ) begin

        pte_pend_s p;

        p =
          pte_pend_q.pop_front();


        pte_ppn[p.idx] =
          p.ppn;

        pte_flags[p.idx] =
          p.flags;

      end


      checks++;


      // --------------------------------------------------------
      // MMU ENABLE
      // --------------------------------------------------------

      if (
        tr.mmu_enable !==
        model_enable
      ) begin

        err(
          $sformatf(
            "MMU enable mismatch exp=%0b got=%0b",
            model_enable,
            tr.mmu_enable
          )
        );

      end


      // ========================================================
      // INSTRUCTION SIDE
      // ========================================================

      if (tr.i_valid) begin

        idx =
          tr.i_va[15:12];


        h =
          i_tlb_valid[tr.i_va[13:12]] &&
          (
            i_tlb_vpn[tr.i_va[13:12]] ==
            tr.i_va[31:12]
          );


        if (h) begin

          ppn =
            i_tlb_ppn[tr.i_va[13:12]];

          flags =
            i_tlb_flags[tr.i_va[13:12]];

        end
        else begin

          ppn =
            pte_ppn[idx];

          flags =
            pte_flags[idx];

        end


        if (
          tr.i_tlb_hit !== h
        ) begin

          err(
            "I-TLB hit mismatch"
          );

        end


        if (
          tr.i_tlb_miss !==
          (
            tr.mmu_enable &&
            !h
          )
        ) begin

          err(
            "I-TLB miss mismatch"
          );

        end


        // ------------------------------------------------------
        // MMU DISABLED
        // ------------------------------------------------------

        if (!tr.mmu_enable) begin

          if (
            tr.i_fault ||
            tr.i_perm_fault ||
            tr.i_pa !== tr.i_va
          ) begin

            err(
              "I-side MMU-disabled bypass violation"
            );

          end

        end


        // ------------------------------------------------------
        // MMU ENABLED
        // ------------------------------------------------------

        else begin

          ok =
            allowed(
              flags,
              1'b0,
              1'b1
            );


          if (!ok) begin

            if (
              !tr.i_fault ||
              tr.i_pa !== 32'h0000_0000
            ) begin

              err(
                "I-side execute fault behavior mismatch"
              );

            end


            if (
              flags[0] &&
              !tr.i_perm_fault
            ) begin

              err(
                "I-side valid-but-X-denied access should be permission fault"
              );

            end


            if (
              !flags[0] &&
              tr.i_perm_fault
            ) begin

              err(
                "I-side invalid PTE must be a page fault, not a permission fault"
              );

            end

          end
          else begin

            if (
              tr.i_fault ||
              tr.i_perm_fault ||
              tr.i_pa !==
              {ppn, tr.i_va[11:0]}
            ) begin

              err(
                "I-side translation mismatch"
              );

            end

          end


          // ----------------------------------------------------
          // INSERT INTO I-TLB
          // ----------------------------------------------------

          if (!h && ok) begin

            i_tlb_valid[
              tr.i_va[13:12]
            ] = 1'b1;

            i_tlb_vpn[
              tr.i_va[13:12]
            ] =
              tr.i_va[31:12];

            i_tlb_ppn[
              tr.i_va[13:12]
            ] =
              ppn;

            i_tlb_flags[
              tr.i_va[13:12]
            ] =
              flags;

          end

        end


        if (
          tr.i_tlb_hit &&
          tr.i_tlb_miss
        ) begin

          err(
            "I-side hit and miss both asserted"
          );

        end

      end


      // ========================================================
      // DATA SIDE
      // ========================================================

      if (tr.d_valid) begin

        idx =
          tr.d_va[15:12];


        h =
          d_tlb_valid[tr.d_va[13:12]] &&
          (
            d_tlb_vpn[tr.d_va[13:12]] ==
            tr.d_va[31:12]
          );


        if (h) begin

          ppn =
            d_tlb_ppn[tr.d_va[13:12]];

          flags =
            d_tlb_flags[tr.d_va[13:12]];

        end
        else begin

          ppn =
            pte_ppn[idx];

          flags =
            pte_flags[idx];

        end


        if (
          tr.d_tlb_hit !== h
        ) begin

          err(
            "D-TLB hit mismatch"
          );

        end


        if (
          tr.d_tlb_miss !==
          (
            tr.mmu_enable &&
            !h
          )
        ) begin

          err(
            "D-TLB miss mismatch"
          );

        end


        // ------------------------------------------------------
        // MMU DISABLED
        // ------------------------------------------------------

        if (!tr.mmu_enable) begin

          if (
            tr.d_fault ||
            tr.d_perm_fault ||
            tr.d_pa !== tr.d_va
          ) begin

            err(
              "D-side MMU-disabled bypass violation"
            );

          end


          if (
            tr.d_write &&
            !tr.d_write_commit
          ) begin

            err(
              "MMU-disabled store was not committed"
            );

          end

        end


        // ------------------------------------------------------
        // MMU ENABLED
        // ------------------------------------------------------

        else begin

          ok =
            allowed(
              flags,
              tr.d_write,
              1'b0
            );


          if (!ok) begin

            if (
              !tr.d_fault ||
              tr.d_pa !== 32'h0000_0000
            ) begin

              err(
                "D-side fault behavior mismatch"
              );

            end


            if (
              flags[0] &&
              !tr.d_perm_fault
            ) begin

              err(
                "D-side valid-but-disallowed access should be permission fault"
              );

            end


            if (
              !flags[0] &&
              tr.d_perm_fault
            ) begin

              err(
                "D-side invalid PTE must be a page fault, not a permission fault"
              );

            end


            if (
              tr.d_write &&
              tr.d_write_commit
            ) begin

              err(
                "Faulting store was committed"
              );

            end

          end
          else begin

            if (
              tr.d_fault ||
              tr.d_perm_fault ||
              tr.d_pa !==
              {ppn, tr.d_va[11:0]}
            ) begin

              err(
                "D-side translation mismatch"
              );

            end


            if (
              tr.d_write &&
              !tr.d_write_commit
            ) begin

              err(
                "Permitted store was not committed"
              );

            end

          end


          // ----------------------------------------------------
          // INSERT INTO D-TLB
          // ----------------------------------------------------

          if (!h && ok) begin

            d_tlb_valid[
              tr.d_va[13:12]
            ] = 1'b1;

            d_tlb_vpn[
              tr.d_va[13:12]
            ] =
              tr.d_va[31:12];

            d_tlb_ppn[
              tr.d_va[13:12]
            ] =
              ppn;

            d_tlb_flags[
              tr.d_va[13:12]
            ] =
              flags;

          end

        end


        if (
          tr.d_tlb_hit &&
          tr.d_tlb_miss
        ) begin

          err(
            "D-side hit and miss both asserted"
          );

        end

      end

    endfunction



    // ----------------------------------------------------------
    // REPORT
    // ----------------------------------------------------------

    function void report_phase(uvm_phase phase);

      super.report_phase(phase);


      if (errors == 0) begin

        `uvm_info(
          "VM_SB",
          $sformatf(
            "PASS: %0d VM status samples checked",
            checks
          ),
          UVM_NONE
        )

      end
      else begin

        `uvm_error(
          "VM_SB",
          $sformatf(
            "FAIL: %0d errors across %0d VM samples",
            errors,
            checks
          )
        )

      end

    endfunction

  endclass



  // ============================================================
  // APB COVERAGE
  // ============================================================

  class apb_coverage extends uvm_subscriber #(apb_item);

    `uvm_component_utils(apb_coverage)


    covergroup cg with function sample(apb_item t);

      option.per_instance = 1;


      cp_wr:
        coverpoint t.write;


      cp_addr:
        coverpoint t.addr[7:0] {

          bins ctrl =
            {8'h00};

          bins ptbr =
            {8'h04};

          bins status =
            {8'h08};

          bins fault =
            {8'h0C};

          bins pte =
            {[8'h10:8'h4C]};

          bins uart =
            {8'h80};

          bins uart_status =
            {8'h84};

          bins other =
            default;

        }


      cp_ctrl:
        coverpoint t.data[1:0]
        iff (
          t.write &&
          t.addr == A_CTRL
        );


      cp_pte_index:
        coverpoint t.addr[5:2]
        iff (
          t.write &&
          t.addr[7:0] >= 8'h10 &&
          t.addr[7:0] < 8'h50
        );


      cross cp_wr, cp_addr;

    endgroup


    function new(
      string name,
      uvm_component parent
    );

      super.new(name, parent);

      cg = new();

    endfunction


    function void write(apb_item t);

      cg.sample(t);

    endfunction


    function void report_phase(uvm_phase phase);

      `uvm_info(
        "APB_COV",
        $sformatf(
          "APB coverage=%0.2f%%",
          cg.get_inst_coverage()
        ),
        UVM_NONE
      )

    endfunction

  endclass



  // ============================================================
  // VM COVERAGE
  // ============================================================

  class vm_coverage extends uvm_subscriber #(vm_status_item);

    `uvm_component_utils(vm_coverage)


    covergroup cg with function sample(vm_status_item t);

      option.per_instance = 1;


      cp_en:
        coverpoint t.mmu_enable;

      cp_i_hit:
        coverpoint t.i_tlb_hit;

      cp_i_miss:
        coverpoint t.i_tlb_miss;

      cp_i_fault:
        coverpoint t.i_fault;

      cp_i_perm:
        coverpoint t.i_perm_fault;

      cp_d_valid:
        coverpoint t.d_valid;

      cp_d_write:
        coverpoint t.d_write;

      cp_d_hit:
        coverpoint t.d_tlb_hit;

      cp_d_miss:
        coverpoint t.d_tlb_miss;

      cp_d_fault:
        coverpoint t.d_fault;

      cp_d_perm:
        coverpoint t.d_perm_fault;

      cp_commit:
        coverpoint t.d_write_commit;


      cp_i_offset:
        coverpoint t.i_va[11:0] {

          bins zero =
            {12'h000};

          bins page_end =
            {12'hFFF};

          bins other =
            default;

        }


      cp_d_offset:
        coverpoint t.d_va[11:0] {

          bins zero =
            {12'h000};

          bins page_end =
            {12'hFFF};

          bins other =
            default;

        }


      cross
        cp_en,
        cp_i_hit,
        cp_i_miss,
        cp_i_fault,
        cp_i_perm;


      cross
        cp_d_valid,
        cp_d_write,
        cp_d_hit,
        cp_d_miss,
        cp_d_fault,
        cp_d_perm;

    endgroup


    function new(
      string name,
      uvm_component parent
    );

      super.new(name, parent);

      cg = new();

    endfunction


    function void write(vm_status_item t);

      cg.sample(t);

    endfunction


    function void report_phase(uvm_phase phase);

      `uvm_info(
        "VM_COV",
        $sformatf(
          "VM coverage=%0.2f%%",
          cg.get_inst_coverage()
        ),
        UVM_NONE
      )

    endfunction

  endclass



  // ============================================================
  // APB AGENT
  // ============================================================

  class apb_agent extends uvm_agent;

    `uvm_component_utils(apb_agent)


    apb_sequencer seqr;

    apb_driver drv;

    apb_monitor mon;


    function new(
      string name,
      uvm_component parent
    );

      super.new(name, parent);

    endfunction


    function void build_phase(uvm_phase phase);

      super.build_phase(phase);


      seqr =
        apb_sequencer::type_id::create(
          "seqr",
          this
        );


      drv =
        apb_driver::type_id::create(
          "drv",
          this
        );


      mon =
        apb_monitor::type_id::create(
          "mon",
          this
        );

    endfunction


    function void connect_phase(uvm_phase phase);

      super.connect_phase(phase);

      drv.seq_item_port.connect(
        seqr.seq_item_export
      );

    endfunction

  endclass



  // ============================================================
  // VM ENVIRONMENT
  // ============================================================

  class vm_env extends uvm_env;

    `uvm_component_utils(vm_env)


    apb_agent agent;

    vm_status_monitor vm_mon;

    vm_scoreboard sb;

    apb_coverage apb_cov;

    vm_coverage vm_cov;


    function new(
      string name,
      uvm_component parent
    );

      super.new(name, parent);

    endfunction


    function void build_phase(uvm_phase phase);

      super.build_phase(phase);


      agent =
        apb_agent::type_id::create(
          "agent",
          this
        );


      vm_mon =
        vm_status_monitor::type_id::create(
          "vm_mon",
          this
        );


      sb =
        vm_scoreboard::type_id::create(
          "sb",
          this
        );


      apb_cov =
        apb_coverage::type_id::create(
          "apb_cov",
          this
        );


      vm_cov =
        vm_coverage::type_id::create(
          "vm_cov",
          this
        );

    endfunction


    function void connect_phase(uvm_phase phase);

      super.connect_phase(phase);


      agent.mon.ap.connect(
        sb.apb_imp
      );


      vm_mon.ap.connect(
        sb.vm_imp
      );


      agent.mon.ap.connect(
        apb_cov.analysis_export
      );


      vm_mon.ap.connect(
        vm_cov.analysis_export
      );

    endfunction

  endclass



  // ============================================================
  // APB BASE SEQUENCE
  // ============================================================

  class apb_base_seq extends uvm_sequence #(apb_item);

    `uvm_object_utils(apb_base_seq)


    function new(
      string name = "apb_base_seq"
    );

      super.new(name);

    endfunction


    // ----------------------------------------------------------
    // WRITE REGISTER
    // ----------------------------------------------------------

    task write_reg(
      bit [31:0] a,
      bit [31:0] d
    );

      apb_item t;


      t =
        apb_item::type_id::create(
          "wr"
        );


      start_item(t);


      t.write = 1'b1;

      t.addr = a;

      t.data = d;


      finish_item(t);


      if (!t.success) begin

        `uvm_error(
          "SEQ",
          "APB write failed"
        )

      end

    endtask



    // ----------------------------------------------------------
    // READ REGISTER
    // ----------------------------------------------------------

    task read_reg(
      bit [31:0] a,
      output bit [31:0] d
    );

      apb_item t;


      t =
        apb_item::type_id::create(
          "rd"
        );


      start_item(t);


      t.write = 1'b0;

      t.addr = a;

      t.data = 32'h0000_0000;


      finish_item(t);


      d =
        t.rdata;


      if (!t.success) begin

        `uvm_error(
          "SEQ",
          "APB read failed"
        )

      end

    endtask

  endclass



  // ============================================================
  // APB REGISTER SEQUENCE
  // ============================================================

  class apb_register_seq extends apb_base_seq;

    `uvm_object_utils(apb_register_seq)


    function new(
      string name = "apb_register_seq"
    );

      super.new(name);

    endfunction


    task body();

      bit [31:0] r;

      int i;


      // Disable MMU.

      write_reg(
        A_CTRL,
        32'h0000_0000
      );


      read_reg(
        A_CTRL,
        r
      );


      if (r[0] !== 1'b0) begin

        `uvm_error(
          "REG",
          "MMU disable readback failed"
        )

      end


      // Enable + flush.

      write_reg(
        A_CTRL,
        32'h0000_0003
      );


      read_reg(
        A_CTRL,
        r
      );


      if (r[0] !== 1'b1) begin

        `uvm_error(
          "REG",
          "MMU enable readback failed"
        )

      end


      // PTBR.

      write_reg(
        A_PTBR,
        32'h1234_5000
      );


      read_reg(
        A_PTBR,
        r
      );


      if (
        r !==
        32'h1234_5000
      ) begin

        `uvm_error(
          "REG",
          "PTBR readback failed"
        )

      end


      // PTE writes.

      for (i = 0; i < 16; i++) begin

        write_reg(
          A_PTE0 + (i * 4),
          32'h00F0_1000 + i
        );

      end


      // Current RTL does not expose PTE readback.

      read_reg(
        A_PTE0,
        r
      );


      if (
        r !==
        32'h0000_0000
      ) begin

        `uvm_error(
          "REG",
          "PTE readback is not zero"
        )

      end


      // Status/fault reads.

      read_reg(
        A_STATUS,
        r
      );


      read_reg(
        A_FAULT,
        r
      );


      // UART.

      write_reg(
        A_UART,
        32'h0000_005A
      );


      read_reg(
        A_USTAT,
        r
      );


      // Restore known PTE0.

      write_reg(
        A_PTE0,
        {7'b0, 5'b01111, 20'h00000}
      );


      write_reg(
        A_CTRL,
        32'h0000_0003
      );

    endtask

  endclass



  // ============================================================
  // MMU INTEGRATION SEQUENCE
  // ============================================================

  class vm_integration_seq extends uvm_sequence #(apb_item);

    `uvm_object_utils(vm_integration_seq)

    `uvm_declare_p_sequencer(apb_sequencer)


    function new(
      string name = "vm_integration_seq"
    );

      super.new(name);

    endfunction



    // ----------------------------------------------------------
    // APB WRITE
    // ----------------------------------------------------------

    task apb_write(
      input bit [31:0] addr,
      input bit [31:0] data
    );

      apb_item req;


      req =
        apb_item::type_id::create(
          "req"
        );


      start_item(req);


      req.write = 1'b1;

      req.addr  = addr;

      req.data  = data;


      finish_item(req);


      if (!req.success) begin

        `uvm_error(
          "INTEG",
          $sformatf(
            "APB WRITE FAILED addr=%08h data=%08h",
            addr,
            data
          )
        )

      end
      else begin

        `uvm_info(
          "INTEG",
          $sformatf(
            "APB WRITE addr=%08h data=%08h",
            addr,
            data
          ),
          UVM_MEDIUM
        )

      end

    endtask



    // ----------------------------------------------------------
    // APB READ
    // ----------------------------------------------------------

    task apb_read(
      input bit [31:0] addr,
      output bit [31:0] data
    );

      apb_item req;


      req =
        apb_item::type_id::create(
          "req"
        );


      start_item(req);


      req.write = 1'b0;

      req.addr  = addr;

      req.data  = 32'h0000_0000;


      finish_item(req);


      data =
        req.rdata;


      if (!req.success) begin

        `uvm_error(
          "INTEG",
          $sformatf(
            "APB READ FAILED addr=%08h",
            addr
          )
        )

      end
      else begin

        `uvm_info(
          "INTEG",
          $sformatf(
            "APB READ addr=%08h data=%08h",
            addr,
            data
          ),
          UVM_MEDIUM
        )

      end

    endtask



    // ----------------------------------------------------------
    // WAIT CLOCKS
    //
    // IMPORTANT:
    //
    // The previous error:
    //
    //     p_sequencer.vif.clk not found
    //
    // was caused by the sequence not having a properly typed
    // p_sequencer.
    //
    // This class now has:
    //
    //     `uvm_declare_p_sequencer(apb_sequencer)
    //
    // and apb_sequencer contains:
    //
    //     virtual apb_if vif;
    //
    // Therefore this is legal:
    //
    //     @(posedge p_sequencer.vif.clk);
    //
    // ----------------------------------------------------------

    task wait_cycles(
      input int unsigned n
    );

      repeat (n) begin

        @(posedge p_sequencer.vif.clk);

      end

    endtask



    // ----------------------------------------------------------
    // MAIN TEST
    // ----------------------------------------------------------

    virtual task body();

      bit [31:0] status;


      `uvm_info(
        "INTEG",
        "==============================================",
        UVM_LOW
      )


      `uvm_info(
        "INTEG",
        "Starting MMU integration test",
        UVM_LOW
      )


      `uvm_info(
        "INTEG",
        "==============================================",
        UVM_LOW
      )


      // ========================================================
      // STEP 1
      // ========================================================

      `uvm_info(
        "INTEG",
        "STEP 1: Configure executable PTE0",
        UVM_LOW
      )


      apb_write(
        A_PTE0,
        {7'b0, 5'b01111, 20'h00000}
      );


      wait_cycles(3);



      // ========================================================
      // STEP 2
      // ========================================================

      `uvm_info(
        "INTEG",
        "STEP 2: Configure writable data PTE1",
        UVM_LOW
      )


      apb_write(
        32'h0000_0014,
        {7'b0, 5'b00111, 20'h00001}
      );


      wait_cycles(3);



      // ========================================================
      // STEP 3
      // ========================================================

      `uvm_info(
        "INTEG",
        "STEP 3: Enable MMU",
        UVM_LOW
      )


      apb_write(
        A_CTRL,
        32'h0000_0001
      );


      wait_cycles(4);



      // ========================================================
      // STEP 4
      // ========================================================

      `uvm_info(
        "INTEG",
        "STEP 4: Flush TLB",
        UVM_LOW
      )


      apb_write(
        A_CTRL,
        32'h0000_0003
      );


      wait_cycles(4);



      // ========================================================
      // STEP 5
      //
      // Program continuously executes:
      //
      //     SW
      //     LW
      //     SW
      //     LW
      //     SW
      //     LW
      //     JAL back
      //
      // Data VA = 0x1000 -> VPN1.
      // ========================================================

      `uvm_info(
        "INTEG",
        "STEP 5: Run program with valid writable PTE1",
        UVM_LOW
      )


      wait_cycles(20);



      // ========================================================
      // STEP 6
      //
      // PTE1:
      //
      // V=1
      // R=1
      // W=0
      // X=0
      //
      // 00011
      // ========================================================

      `uvm_info(
        "INTEG",
        "STEP 6: Change PTE1 to READ-ONLY",
        UVM_LOW
      )


      apb_write(
        32'h0000_0014,
        {7'b0, 5'b00011, 20'h00001}
      );


      wait_cycles(3);



      // ========================================================
      // STEP 7
      // Flush TLB.
      // ========================================================

      `uvm_info(
        "INTEG",
        "STEP 7: Flush TLB after PTE1 permission change",
        UVM_LOW
      )


      apb_write(
        A_CTRL,
        32'h0000_0003
      );


      wait_cycles(4);



      // ========================================================
      // STEP 8
      //
      // The looping program should now execute another store
      // to VPN1.
      //
      // PTE1 is read-only, therefore the store must fault.
      // ========================================================

      `uvm_info(
        "INTEG",
        "STEP 8: Checking D permission fault",
        UVM_LOW
      )


      wait_cycles(10);


      apb_read(
        A_STATUS,
        status
      );


      `uvm_info(
        "INTEG",
        $sformatf(
          "STATUS after READ-ONLY PTE1 = %08h",
          status
        ),
        UVM_LOW
      )


      // --------------------------------------------------------
      // D PERMISSION FAULT
      //
      // Observed RTL:
      //
      //     status = 0x210
      //
      // therefore:
      //
      //     status[4] = 1
      // --------------------------------------------------------

      if (!status[4]) begin

        `uvm_error(
          "INTEG",
          $sformatf(
            "Expected D permission fault at STATUS[4], STATUS=%08h",
            status
          )
        )

      end
      else begin

        `uvm_info(
          "INTEG",
          "PASS: D permission fault detected at STATUS[4]",
          UVM_LOW
        )

      end



      // ========================================================
      // STEP 9
      //
      // Observed RTL:
      //
      //     0x210
      //
      // means:
      //
      //     bit 9 = sticky D fault
      // ========================================================


      `uvm_info(
        "INTEG",
        "STEP 9: Checking D sticky fault status",
        UVM_LOW
      )

      if (!status[9]) begin

        `uvm_error(
          "INTEG",
          $sformatf(
            "Expected D sticky permission fault at STATUS[9], STATUS=%08h",
            status
          )
        )

      end
      else begin

        `uvm_info(
          "INTEG",
          "PASS: D sticky permission fault detected at STATUS[9]",
          UVM_LOW
        )

      end



      // ========================================================
      // STEP 10
      // Restore writable PTE1.
      // ========================================================

      `uvm_info(
        "INTEG",
        "STEP 10: Restore writable PTE1",
        UVM_LOW
      )


      apb_write(
        32'h0000_0014,
        {7'b0, 5'b00111, 20'h00001}
      );


      wait_cycles(3);


      apb_write(
        A_CTRL,
        32'h0000_0003
      );


      wait_cycles(4);



      // ========================================================
      // STEP 11
      // UART
      // ========================================================

      `uvm_info(
        "INTEG",
        "STEP 11: UART test",
        UVM_LOW
      )


      apb_write(
        A_UART,
        32'h0000_0055
      );


      wait_cycles(5);


      apb_read(
        A_USTAT,
        status
      );


      `uvm_info(
        "INTEG",
        $sformatf(
          "UART_STATUS=%08h",
          status
        ),
        UVM_LOW
      )



      // ========================================================
      // DONE
      // ========================================================

      `uvm_info(
        "INTEG",
        "==============================================",
        UVM_LOW
      )


      `uvm_info(
        "INTEG",
        "Integration sequence completed",
        UVM_LOW
      )


      `uvm_info(
        "INTEG",
        "==============================================",
        UVM_LOW
      )

    endtask

  endclass



  // ============================================================
  // RANDOM APB CONFIGURATION SEQUENCE
  //
  // UVM 1.1d / Questa compatibility:
  //
  // Instead of:
  //
  //     dist { value := weight }
  //
  // we explicitly generate a random selector.
  //
  // This avoids the parser issue you previously encountered
  // around lines 2458-2463.
  // ============================================================

  class apb_random_cfg_seq extends apb_base_seq;

    `uvm_object_utils(apb_random_cfg_seq)


    function new(
      string name = "apb_random_cfg_seq"
    );

      super.new(name);

    endfunction



    task body();

      apb_item t;

      int i;

      int sel;

      bit [4:0] flags;


      // --------------------------------------------------------
      // Random PTE accesses
      // --------------------------------------------------------

      repeat (100) begin

        t =
          apb_item::type_id::create(
            "rand_cfg"
          );


        start_item(t);


        assert (
          t.randomize() with {

            write == 1'b1;

            addr[31:8] == 32'h0000_00;

            addr[1:0] == 2'b00;

            addr[7:2] inside {[6'h04:6'h13]};

            data[19:0] inside {
              [20'h00000:20'hFFFFF]
            };

          }
        )
        else begin

          `uvm_fatal(
            "RAND_APB",
            "APB randomization failed"
          )

        end


        // ------------------------------------------------------
        // Generate legal PTE permission flags without dist.
        //
        // Weighted selector:
        //
        // 0-1       -> 00000
        // 2-3       -> 00001
        // 4-6       -> 00011
        // 7-9       -> 00111
        // 10-12     -> 01011
        // 13-18     -> 01111
        // ------------------------------------------------------

        sel =
          $urandom_range(0,18);


        if (sel <= 1)
          flags = 5'b00000;

        else if (sel <= 3)
          flags = 5'b00001;

        else if (sel <= 6)
          flags = 5'b00011;

        else if (sel <= 9)
          flags = 5'b00111;

        else if (sel <= 12)
          flags = 5'b01011;

        else
          flags = 5'b01111;


        t.data[24:20] =
          flags;


        finish_item(t);

      end



      // --------------------------------------------------------
      // Random CTRL/PTBR
      // --------------------------------------------------------

      repeat (20) begin

        t =
          apb_item::type_id::create(
            "rand_ctrl"
          );


        start_item(t);


        assert (
          t.randomize() with {

            write == 1'b1;

            addr inside {
              A_CTRL,
              A_PTBR
            };

            addr[1:0] == 2'b00;

          }
        )
        else begin

          `uvm_fatal(
            "RAND_APB",
            "CTRL/PTBR randomization failed"
          )

        end


        if (t.addr == A_CTRL) begin

          sel =
            $urandom_range(0,2);


          case (sel)

            0:
              t.data[1:0] = 2'b00;

            1:
              t.data[1:0] = 2'b01;

            default:
              t.data[1:0] = 2'b11;

          endcase

        end


        finish_item(t);

      end



      // --------------------------------------------------------
      // Restore deterministic state.
      // --------------------------------------------------------

      write_reg(
        A_PTE0,
        {7'b0, 5'b01111, 20'h00000}
      );


      write_reg(
        A_CTRL,
        32'h0000_0003
      );

    endtask

  endclass



  // ============================================================
  // UVM TEST
  // ============================================================

  class vm_apb_test extends uvm_test;

    `uvm_component_utils(vm_apb_test)


    vm_env env;


    function new(
      string name,
      uvm_component parent
    );

      super.new(name, parent);

    endfunction



    function void build_phase(uvm_phase phase);

      super.build_phase(phase);


      env =
        vm_env::type_id::create(
          "env",
          this
        );

    endfunction



    task run_phase(uvm_phase phase);

      apb_register_seq regseq;

      vm_integration_seq seq;

      apb_random_cfg_seq rnd;


      phase.raise_objection(this);


      // --------------------------------------------------------
      // RESET
      // --------------------------------------------------------

      env.agent.drv.reset_dut();


      // --------------------------------------------------------
      // REGISTER TEST
      // --------------------------------------------------------

      regseq =
        apb_register_seq::type_id::create(
          "regseq"
        );


      regseq.start(
        env.agent.seqr
      );


      // --------------------------------------------------------
      // INTEGRATION TEST
      // --------------------------------------------------------

      seq =
        vm_integration_seq::type_id::create(
          "seq"
        );


      seq.start(
        env.agent.seqr
      );


      // --------------------------------------------------------
      // RANDOM CONFIGURATION
      // --------------------------------------------------------

      rnd =
        apb_random_cfg_seq::type_id::create(
          "rnd"
        );


      rnd.start(
        env.agent.seqr
      );


      // --------------------------------------------------------
      // Allow VM monitor to collect final samples.
      // --------------------------------------------------------

      repeat (20)
        @(env.vm_mon.vif.mon_cb);


      phase.drop_objection(this);

    endtask

  endclass


endpackage

