package vm_apb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class apb_item extends uvm_sequence_item;
    rand bit write;
    rand bit [31:0] addr;
    rand bit [31:0] data;
    bit [31:0] rdata;
    `uvm_object_utils_begin(apb_item)
      `uvm_field_int(write,UVM_ALL_ON)
      `uvm_field_int(addr,UVM_ALL_ON)
      `uvm_field_int(data,UVM_ALL_ON)
      `uvm_field_int(rdata,UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="apb_item"); super.new(name); endfunction
  endclass

  class vm_status_item extends uvm_sequence_item;
    bit mmu_enable;
    bit [31:0] i_va, i_pa, d_va, d_pa;
    bit i_valid, d_valid, d_write, d_write_commit;
    bit i_fault, d_fault, i_perm_fault, d_perm_fault;
    bit i_tlb_hit, d_tlb_hit, i_tlb_miss, d_tlb_miss;
    `uvm_object_utils(vm_status_item)
    function new(string name="vm_status_item"); super.new(name); endfunction
  endclass

  class apb_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_driver)
    virtual apb_if vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual apb_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","APB interface missing")
    endfunction
    task drive_one(apb_item tr);
      vif.master_cb.psel <= 1'b1;
      vif.master_cb.penable <= 1'b0;
      vif.master_cb.pwrite <= tr.write;
      vif.master_cb.paddr <= tr.addr;
      vif.master_cb.pwdata <= tr.data;
      @(vif.master_cb);
      vif.master_cb.penable <= 1'b1;
      do @(vif.master_cb); while(!vif.master_cb.pready);
      if(!tr.write) tr.rdata = vif.master_cb.prdata;
      vif.master_cb.psel <= 1'b0;
      vif.master_cb.penable <= 1'b0;
      vif.master_cb.pwrite <= 1'b0;
    endtask
    task run_phase(uvm_phase phase);
      apb_item tr;
      vif.master_cb.psel <= 0; vif.master_cb.penable <= 0; vif.master_cb.pwrite <= 0;
      vif.master_cb.paddr <= 0; vif.master_cb.pwdata <= 0;
      forever begin
        seq_item_port.get_next_item(tr);
        drive_one(tr);
        seq_item_port.item_done();
      end
    endtask
  endclass

  class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    virtual apb_if vif;
    uvm_analysis_port #(apb_item) ap;
    function new(string name, uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual apb_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","APB interface missing")
    endfunction
    task run_phase(uvm_phase phase);
      apb_item tr;
      forever begin
        @(posedge vif.clk);
        if(vif.psel && vif.penable && vif.pready) begin
          tr=apb_item::type_id::create("tr",this);
          tr.write=vif.pwrite; tr.addr=vif.paddr; tr.data=vif.pwdata; tr.rdata=vif.prdata;
          ap.write(tr);
        end
      end
    endtask
  endclass

  class vm_status_monitor extends uvm_monitor;
    `uvm_component_utils(vm_status_monitor)
    virtual vm_status_if vif;
    uvm_analysis_port #(vm_status_item) ap;
    function new(string name, uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual vm_status_if)::get(this,"","status_vif",vif)) `uvm_fatal("NOVSTATUS","VM status interface missing")
    endfunction
    task run_phase(uvm_phase phase);
      vm_status_item tr;
      forever begin
        @(posedge vif.clk);
        if(!vif.reset) begin
          tr=vm_status_item::type_id::create("vmst",this);
          tr.mmu_enable=vif.mmu_enable; tr.i_va=vif.i_va; tr.i_pa=vif.i_pa;
          tr.d_va=vif.d_va; tr.d_pa=vif.d_pa; tr.i_valid=vif.i_valid; tr.d_valid=vif.d_valid;
          tr.d_write=vif.d_write; tr.d_write_commit=vif.d_write_commit; tr.i_fault=vif.i_fault; tr.d_fault=vif.d_fault;
          tr.i_perm_fault=vif.i_perm_fault; tr.d_perm_fault=vif.d_perm_fault;
          tr.i_tlb_hit=vif.i_tlb_hit; tr.d_tlb_hit=vif.d_tlb_hit;
          tr.i_tlb_miss=vif.i_tlb_miss; tr.d_tlb_miss=vif.d_tlb_miss;
          ap.write(tr);
        end
      end
    endtask
  endclass

  `uvm_analysis_imp_decl(_apb)
  `uvm_analysis_imp_decl(_vm)

  class vm_scoreboard extends uvm_component;
    `uvm_component_utils(vm_scoreboard)
    uvm_analysis_imp_apb #(apb_item,vm_scoreboard) apb_imp;
    uvm_analysis_imp_vm  #(vm_status_item,vm_scoreboard) vm_imp;
    bit mmu_enable_model=1'b1;
    bit [19:0] pte_ppn[16];
    bit [4:0]  pte_flags[16];
    integer errors;
    function new(string name, uvm_component parent);
      super.new(name,parent); apb_imp=new("apb_imp",this); vm_imp=new("vm_imp",this); errors=0;
      foreach(pte_ppn[i]) begin pte_ppn[i]=0; pte_flags[i]=0; end
      pte_ppn[0]=0; pte_flags[0]=5'b01111;
    endfunction
    function void write_apb(apb_item tr);
      integer idx;
      if(tr.write && tr.addr==32'h00) begin
        mmu_enable_model=tr.data[0];
      end else if(tr.write && tr.addr>=32'h10 && tr.addr<32'h50 && tr.addr[1:0]==0) begin
        idx=(tr.addr[5:2]-4);
        pte_ppn[idx]=tr.data[19:0]; pte_flags[idx]=tr.data[24:20];
        `uvm_info("SB",$sformatf("PTE[%0d] <= PPN=%05h FLAGS=%02h",idx,pte_ppn[idx],pte_flags[idx]),UVM_MEDIUM)
      end else if(!tr.write && tr.addr==32'h00) begin
        if(tr.rdata[0]!==mmu_enable_model) begin errors++; `uvm_error("SB","CTRL readback mismatch"); end
      end
    endfunction
    function void write_vm(vm_status_item tr);
      integer idx; bit valid, allowed;
      if(!tr.mmu_enable) begin
        if(tr.i_valid && (tr.i_pa!==tr.i_va)) begin errors++; `uvm_error("SB","I bypass translation mismatch"); end
        if(tr.d_valid && (tr.d_pa!==tr.d_va) && !tr.d_fault) begin errors++; `uvm_error("SB","D bypass translation mismatch"); end
      end else begin
        if(tr.i_valid) begin
          idx=tr.i_va[15:12]; valid=pte_flags[idx][0]; allowed=pte_flags[idx][3];
          if(valid && allowed && !tr.i_fault && tr.i_pa!=={pte_ppn[idx],tr.i_va[11:0]}) begin errors++; `uvm_error("SB","I PA mismatch"); end
        end
        if(tr.d_valid) begin
          idx=tr.d_va[15:12]; valid=pte_flags[idx][0];
          allowed=tr.d_write ? pte_flags[idx][2] : pte_flags[idx][1];
          if((!valid || !allowed) && !tr.d_fault) begin errors++; `uvm_error("SB","D expected fault missing"); end
          if(valid && allowed && !tr.d_fault && tr.d_pa!=={pte_ppn[idx],tr.d_va[11:0]}) begin errors++; `uvm_error("SB","D PA mismatch"); end
        end
      end
    endfunction
    function void report_phase(uvm_phase phase);
      if(errors==0) `uvm_info("SB","VM UVM SCOREBOARD PASSED",UVM_NONE)
      else `uvm_error("SB",$sformatf("VM UVM SCOREBOARD ERRORS=%0d",errors));
    endfunction
  endclass

  class vm_coverage extends uvm_component;
    `uvm_component_utils(vm_coverage)
    uvm_analysis_imp_apb #(apb_item,vm_coverage) apb_imp;
    uvm_analysis_imp_vm  #(vm_status_item,vm_coverage) vm_imp;
    covergroup apb_cg with function sample(bit wr, bit [7:0] addr, bit [31:0] data);
      cp_wr: coverpoint wr;
      cp_addr: coverpoint addr { bins ctrl={8'h00}; bins ptbr={8'h04}; bins status={8'h08}; bins fault={8'h0C}; bins pte={[8'h10:8'h4C]}; bins uart={8'h80}; }
      cp_ctrl: coverpoint data[1:0] iff(addr==8'h00);
      cross cp_wr,cp_addr;
    endgroup
    covergroup vm_cg with function sample(bit is_d, bit wr, bit hit, bit miss, bit fault, bit perm);
      cp_side: coverpoint is_d;
      cp_write: coverpoint wr;
      cp_hit: coverpoint hit;
      cp_miss: coverpoint miss;
      cp_fault: coverpoint fault;
      cp_perm: coverpoint perm;
      cross cp_side,cp_hit,cp_miss,cp_fault,cp_perm;
    endgroup
    function new(string name, uvm_component parent); super.new(name,parent); apb_imp=new("apb_imp",this); vm_imp=new("vm_imp",this); apb_cg=new(); vm_cg=new(); endfunction
    function void write_apb(apb_item tr); apb_cg.sample(tr.write,tr.addr[7:0],tr.data); endfunction
    function void write_vm(vm_status_item tr);
      vm_cg.sample(0,0,tr.i_tlb_hit,tr.i_tlb_miss,tr.i_fault,tr.i_perm_fault);
      if(tr.d_valid) vm_cg.sample(1,tr.d_write,tr.d_tlb_hit,tr.d_tlb_miss,tr.d_fault,tr.d_perm_fault);
    endfunction
    function void report_phase(uvm_phase phase);
      `uvm_info("COV",$sformatf("APB coverage=%0.2f%% VM coverage=%0.2f%%",apb_cg.get_inst_coverage(),vm_cg.get_inst_coverage()),UVM_NONE)
    endfunction
  endclass

  class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)
    apb_driver drv; apb_monitor mon; uvm_sequencer #(apb_item) seqr;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase); seqr=uvm_sequencer#(apb_item)::type_id::create("seqr",this);
      drv=apb_driver::type_id::create("drv",this); mon=apb_monitor::type_id::create("mon",this);
    endfunction
    function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(seqr.seq_item_export); endfunction
  endclass

  class vm_env extends uvm_env;
    `uvm_component_utils(vm_env)
    apb_agent agent; vm_status_monitor vm_mon; vm_scoreboard sb; vm_coverage cov;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase); agent=apb_agent::type_id::create("agent",this);
      vm_mon=vm_status_monitor::type_id::create("vm_mon",this);
      sb=vm_scoreboard::type_id::create("sb",this); cov=vm_coverage::type_id::create("cov",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      agent.mon.ap.connect(sb.apb_imp); vm_mon.ap.connect(sb.vm_imp);
      agent.mon.ap.connect(cov.apb_imp); vm_mon.ap.connect(cov.vm_imp);
    endfunction
  endclass

  class vm_apb_seq extends uvm_sequence #(apb_item);
    `uvm_object_utils(vm_apb_seq)
    function new(string name="vm_apb_seq"); super.new(name); endfunction
    task apb_write(bit [31:0] a, bit [31:0] d);
      apb_item tr=apb_item::type_id::create("wr"); start_item(tr); tr.write=1; tr.addr=a; tr.data=d; finish_item(tr);
    endtask
    task apb_read(bit [31:0] a);
      apb_item tr=apb_item::type_id::create("rd"); start_item(tr); tr.write=0; tr.addr=a; tr.data=0; finish_item(tr);
    endtask
    task body();
      // Enable + flush; program VPN1->PPN2 RWX.
      apb_write(32'h00,32'h3);
      apb_write(32'h14,{7'b0,5'b01111,20'h2});
      apb_read(32'h00);
      apb_read(32'h08);
      apb_read(32'h0C);
      apb_write(32'h80,32'h00000056);
      // Invalid mapping and permission-fault mapping are exercised by the
      // supplied CPU program/testbench as well as the dedicated MMU unit test.
    endtask
  endclass

  class vm_apb_test extends uvm_test;
    `uvm_component_utils(vm_apb_test)
    vm_env env;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); env=vm_env::type_id::create("env",this); endfunction
    task run_phase(uvm_phase phase);
      vm_apb_seq seq=vm_apb_seq::type_id::create("seq");
      phase.raise_objection(this); seq.start(env.agent.seqr); repeat(200) @(env.vm_mon.vif.clk); phase.drop_objection(this);
    endtask
  endclass
endpackage
