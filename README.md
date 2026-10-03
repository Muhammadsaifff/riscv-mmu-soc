# RISC-V MMU SoC

This repository contains the Verilog implementation of a RISC-V processor with Memory Management Unit (MMU) support, designed for System-on-Chip (SoC) applications. The project utilizes the SKY130 PDK and is intended for ASIC design flows.

## Project Overview

The `riscv-mmu-soc` project aims to provide a configurable RISC-V core with MMU capabilities, suitable for embedded systems requiring virtual memory management. The design is implemented in Verilog and targets the SKY130 technology node, implying a focus on custom silicon development.

## Table of Contents

- [Project Overview](#project-overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Installation](#installation)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)

## Features ✨

- **RISC-V Core:** Implements a RISC-V instruction set architecture.
- **Memory Management Unit (MMU):** Supports virtual memory, crucial for modern operating systems and complex applications.
- **SKY130 PDK:** Designed and verified using the SKY130 Process Design Kit, making it suitable for tape-out.
- **ASIC Design Flow:** Tailored for ASIC implementation, including configurations for synthesis, place & route, and static timing analysis.
- **SRAM Macro Integration:** Demonstrates integration of SRAM macros for data memory.
- **Verilog Implementation:** Core logic is written in Verilog.
- **Configurable Design:** Utilizes configuration files (YAML, JSON) for tool settings and design parameters.
- **Extensive Checks:** Includes multiple checker steps for linting, timing constructs, unmapped cells, and power grid violations.

## Tech Stack 💻

- **Hardware Description Language:** Verilog
- **Configuration:** YAML, JSON
- **Design Flow Tools:** Verilator, Yosys, OpenROAD (implied by config files)
- **PDK:** SKY130A
- **Frameworks (detected in analysis, likely for tooling or scripting):** TypeScript, Python, Rails

## Installation 🛠️

The project setup appears to be heavily reliant on specific toolchains and PDKs, indicated by the absolute paths in the configuration files (e.g., `/home/ayesha/.ciel/ciel/sky130/...`). A typical installation would involve:

1.  **Setting up the build environment:** Ensure necessary EDA tools (Verilator, Yosys, OpenROAD) are installed and configured.
2.  **Obtaining the SKY130 PDK:** Download and install the SKY130 Analog/Mixed-Signal Design Kit.
3.  **Configuring the PDK Paths:** Update paths in configuration files (e.g., `PDK_ROOT`, `TECH_LEFS`, `LIB`) to point to your local installation of the SKY130 PDK and associated libraries.
4.  **Cloning the Repository:**
    ```bash
    git clone https://github.com/Muhammadsaifff/riscv-mmu-soc.git
    cd riscv-mmu-soc
    ```
5.  **Running the Build/Verification Flow:** The exact commands would depend on the project's build scripts (not explicitly detailed in the provided analysis but likely present in `riscv_mmu_fpga/riscv_mmu/Makefile`). A common pattern might involve:
    ```bash
    make verify  # or a similar target
    ```

**Note:** The provided configuration files point to a specific user's local setup (`/home/ayesha/...`). These paths will need to be adjusted for your environment.

## Usage 🚀

The project is designed for ASIC implementation and verification. Key usage scenarios involve:

-   **Synthesizing the Design:** Using Yosys with the provided configuration to synthesize the Verilog code into a gate-level netlist.
-   **Place and Route:** Employing tools like OpenROAD to perform floorplanning, placement, and routing.
-   **Verification:** Running simulations and formal checks (linting, timing, power grid checks) to ensure design correctness and adherence to specifications.

### Example Configuration Snippet (from `01-verilator-lint/config.json`)

This configuration snippet shows the setup for Verilator linting, including standard cell library information and various Static Timing Analysis (STA) corners:

```json
{
    "STD_CELL_LIBRARY": "sky130_fd_sc_hd",
    "VDD_PIN": "VPWR",
    "GND_PIN": "VGND",
    "STA_CORNERS": [
        "nom_tt_025C_1v80",
        "nom_ss_100C_1v60",
        "nom_ff_n40C_1v95",
        "min_tt_025C_1v80",
        "min_ss_100C_1v60",
        "min_ff_n40C_1v95",
        "max_tt_025C_1v80",
        "max_ss_100C_1v60",
        "max_ff_n40C_1v95"
    ],
    "CLOCK_PERIOD": 10,
    "CLOCK_PORT": "clk",
    "DESIGN_NAME": "SoC_Hardened"
}
```

## Project Structure 📁

Based on the file paths, the project appears to be structured as follows:

```
riscv-mmu-soc/
├── riscv_mmu_fpga/
│   └── riscv_mmu/
│       ├── Makefile
│       ├── Single_Cycle_RV32I.v
│       ├── Top.v
│       ├── ... (other Verilog files)
│       └── flow.json
├── riscv_mmu_pd/
│   ├── config.yaml
│   ├── runs/
│   │   └── RUN_2026-09-13_10-44-24/
│   │       ├── 01-verilator-lint/
│   │       │   └── config.json
│   │       ├── 02-checker-linttimingconstructs/
│   │       │   └── config.json
│   │       ├── ... (other checker and tool run configurations)
│   │       ├── 28-openroad-globalplacement/
│   │       │   └── config.json
│   │       └── ...
│   ├── MEMORY_SYNTH_OPTIMIZATION.md
│   ├── Single_Cycle_RV32I.v
│   ├── SoC_Hardened.v
│   ├── Top.v
│   ├── ... (other Verilog source files)
│   ├── impl.sdc
│   └── signoff.sdc
└── README.md
```

-   `riscv_mmu_fpga/`: Contains FPGA-related Verilog sources and build files.
-   `riscv_mmu_pd/`: Contains the Verilog sources for the ASIC implementation, along with configuration and run data.
    -   `runs/`: This directory holds detailed configuration for various stages of the ASIC flow (linting, synthesis, placement, routing, checking).
-   `README.md`: The main README file.

## Dependencies 📦

-   **Verilog Toolchain:** Verilator, Yosys.
-   **Physical Design Tools:** OpenROAD (implied by configuration files).
-   **PDK:** SKY130A (and associated libraries, LEFs, GDS, etc.).
-   **Python:** Likely required for scripting and tool execution.
-   **TypeScript, Rails:** Mentioned in the analysis summary, potentially used for tooling or web-based interfaces if any exist.

## How to Use 🛠️

This project appears to be a collection of Verilog modules and configuration files for an ASIC design flow. To utilize this project:

1.  **Set up the Environment:** Ensure you have a working environment with Verilog simulation/synthesis tools (like Verilator, Yosys) and an ASIC P&R toolchain (like OpenROAD) installed and configured.
2.  **Configure PDK Paths:** Critically, you must update the absolute paths within the various `config.json` and `.yaml` files (especially in the `runs/` directory) to point to your local installation of the SKY130 PDK and its libraries.
3.  **Run Synthesis:** Execute the synthesis flow, likely through a Makefile target or by invoking Yosys with the appropriate configuration files.
4.  **Perform Place and Route:** Use OpenROAD or a similar toolchain to perform floorplanning, placement, and routing based on the synthesized netlist and SDC constraints.
5.  **Verification:** Utilize the checker configurations (linting, timing, etc.) to validate the design at various stages.

## Contributing 📝

Contributions are welcome! Please refer to the standard contributing guidelines for open-source hardware projects. Typically, this would involve:

1.  Forking the repository.
2.  Creating a new branch for your feature or bug fix.
3.  Making your changes and ensuring they are well-tested.
4.  Submitting a pull request.

## License 📄

This project does not explicitly state a license in the provided information. It's crucial to check the repository for a `LICENSE` file or mention in the README for licensing details. As a default, un-licensed code is generally not open for redistribution or modification without explicit permission.

Feel free to fork, star, and issue pull requests! ⭐


---
