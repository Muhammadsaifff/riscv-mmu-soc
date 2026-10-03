current_dir := ${CURDIR}
TOP := fpga_top
SOURCES := ${current_dir}/fpga_top.v \
           ${current_dir}/Top.v \
           ${current_dir}/Single_Cycle_RV32I.v \
           ${current_dir}/alu32.v \
           ${current_dir}/control_logic.v \
           ${current_dir}/datapath.v \
           ${current_dir}/regfile.v \
           ${current_dir}/adder.v \
           ${current_dir}/extend.v \
           ${current_dir}/flopr.v \
           ${current_dir}/mux2.v \
           ${current_dir}/mux4.v \
           ${current_dir}/mmu.v \
           ${current_dir}/tlb.v \
           ${current_dir}/page_table.v \
           ${current_dir}/fault_handler.v \
           ${current_dir}/apb_mmu_control.v \
           ${current_dir}/uart_tx.v \
           ${current_dir}/gpio_debug.v \
           ${current_dir}/imem.v \
           ${current_dir}/dmem.v

ifeq ($(TARGET),arty_35)
ifdef F4PGA_USE_DEPRECATED
  XDC := ${current_dir}/arty.xdc
else
build:
	f4pga -vv build --flow ./flow.json
endif
else ifeq ($(TARGET),arty_100)
  XDC := ${current_dir}/arty.xdc
else ifeq ($(TARGET),nexys4ddr)
  XDC := ${current_dir}/nexys4ddr.xdc
else ifeq ($(TARGET),zybo)
  XDC := ${current_dir}/zybo.xdc
  SOURCES:=${current_dir}/counter_zynq.v
else ifeq ($(TARGET),nexys_video)
  XDC := ${current_dir}/nexys_video.xdc
else ifeq ($(TARGET),basys3)
  XDC := ${current_dir}/basys3.xdc
endif

include ${current_dir}/../../common/common.mk
