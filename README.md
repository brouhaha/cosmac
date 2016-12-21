# cosmac - RCA COSMAC CDP1802 functional equivalent CPU core in VHDL

Copyright 2009, 2010, 2016 Eric Smith <spacewar@gmail.com>

cosmac development is hosted at the
[cosmac Github repository](https://github.com/brouhaha/cosmac/).

## Introduction

The RCA "COSMAC" CDP1802 microprocessor was one of the earliest
CMOS microprocessors, introduced in 1976.  Compared to the contemporary
NMOS microprocessors, the 1802 was slower, but consumed _much_ less
power.

This project contains an implementation of a CPU core in VHDL
(cosmac.vhdl) which is object-code compatible with the CDP1802.  The
electrical interface is similar to the CDP1802 but not identical; in
particular each CDP1802 machine cycles requires eight clock cycles,
while this core only requires a single clock cycle.

The CPU core is written in synthesizable VHDL, with no vendor-specific
constructs.

Additional VHDL files are provided in the elf directory for a
demonstration system for use in Xilinx FPGAs.  The demo is equivalent
to a COSMAC ELF microcontroller, as described in a series of Popular
Electronics articles in 1976.  The demo runs on a Xilinx XC3S1600E
evaluation board, requiring that switches and LEDs be interfaced.


## Source files:

CPU core:

| Filename             | Description                               |
| -------------------- | ----------------------------------------- |
| cosmac.vhdl          | CPU core                                  |

COSMAC ELF Demonstration project for Xilinx FPGA, in elf directory:

| Filename             | Description                               |
| -------------------- | ----------------------------------------- |
| dcm_wrapper.vhdl     | clock manager for Xilinx FPGA             |
| debouncer.vhdl       | general purpose switch debouncer          |
| elf_ram_256.vhdl     | 256 byte RAM using Xilinx FPGA block RAM  |
| elf.vhdl             | top-level design                          |
| reset_gen.vhdl       | reset generator                           |


## Status

The following features of the core have been tested and appear
to work correctly:
* Most of the instruction set has been tested by running
  [CamelForth](http://www.camelforth.com/news.php).
* The DMA input and "load mode" capability have been tested by using
  the core as part of a COSMAC ELF equivalent.

The following features have not been tested:
* The interrupt feature of the core and the related instructions have
  not been tested.
* The DMA output feature has not been tested.


## License information:

For licensing purposes, the VHDL files both individually and
collectively, with the exception of dcm_wrapper.vhdl, are considered a
"program", licensed under the terms of the GNU General Public License
3.0, which is provided in the file gpl-3.0.txt.  If you distribute
this program as part of a derived work (including but not limited to
use in an FPGA or ASIC), the license imposes obligations on you to
make the source code for the entire work available.  No one forces you
to accept this license, but if you choose not to accept it, nothing
authorizes you to distribute this program.

If you wish to use this program as part of a derived work, but without
the obligations imposed by the GPL license, contact the author regarding
alternative licensing.
