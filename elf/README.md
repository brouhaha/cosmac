# COSMAC ELF microcomputer in VHDL

Copyright 2009, 2010, 2016 Eric Smith <spacewar@gmail.com>

cosmac development is hosted at the
[cosmac Github repository](https://github.com/brouhaha/cosmac/).

## Introduction

The COSMAC ELF microcomputer was described in a series of articles in
Popular Electronics in 1976.  The VHDL files in this directory, when
used with the cosmac.vhdl CPU core in the parent directory, provide the
equivalent of a COSMAC ELF microcomputer.  As provided it is configured
to run on a Xilinx XC3S1600E evaluation board, requiring that switches
and LEDs be interfaced.


## Source files:

COSMAC ELF Demonstration project for Xilinx FPGA:

| Filename             | Description                               |
| -------------------- | ----------------------------------------- |
| dcm_wrapper.vhdl     | clock manager for Xilinx FPGA             |
| debouncer.vhdl       | general purpose switch debouncer          |
| elf_ram_256.vhdl     | 256 byte RAM using Xilinx FPGA block RAM  |
| elf.vhdl             | top-level design                          |
| reset_gen.vhdl       | reset generator                           |


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
