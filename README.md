# cosmac - RCA COSMAC CDP1802 functional equivalent CPU core in VHDL

Copyright 2009, 2010, 2016, 2017 Eric Smith <spacewar@gmail.com>

cosmac development is hosted at the
[cosmac Github repository](https://github.com/brouhaha/cosmac/).

## Introduction

The RCA "COSMAC" CDP1802 microprocessor was one of the earliest
CMOS microprocessors, introduced in 1976.  Compared to the contemporary
NMOS microprocessors, the 1802 was slower, but consumed _much_ less
power.

This project contains an implementation of a CPU core in VHDL
(cosmac.vhdl) which is object-code compatible with the CDP1802.  The
CPU core is written in synthesizable VHDL, with no vendor-specific
constructs.

The electrical interface of the core is similar to the CDP1802 but not
identical. Due to the lack of true bidirectional signals in FPGAs,
there are separate 8-bit data bus inputs and outputs.

The core executes each machine cycle in one clock cycle, whereas the
CDP1802 required eight clock cycles per machine cycle.  In a Xilinx
XC3S1600E FPGA, the core can run with a 25 MHz clock, giving it
performance equivalent to a 200 MHz CDP1802.


## COSMAC ELF Demonstration system

A demonstration system equivalent to a COSMAC ELF microcomputer,
as described in a series of Popular Electronics articles in 1976,
is provided in the elf directory.

Additional hardware-specific files are needed depending on what
FPGA you are using. For some FPGAs, suitable files are provided:

| Directory | Description                                   | Status                    |
| --------- | --------------------------------------------- | ------------------------- |
| elf-x7    | Xilinx 7-Series FPGAs (e.g. XC7A100T-1FGG484) | tested 2017-01-01         |


## Source files

CPU core:

| Filename             | Description                               |
| -------------------- | ----------------------------------------- |
| cosmac.vhdl          | CPU core                                  |


COSMAC ELF demo:

| Filename             | Description                               |
| -------------------- | ----------------------------------------- |
| elf.vhdl             | COSMAC ELF control and interconnect       |
| debouncer.vhdl       | general-purpose switch debouncer          |
| memory.vhdl          | 64KB static RAM                           |


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


## License information

For licensing purposes, the VHDL source files (with the exception of
elf-s3e/dcm_wrapper.vhdl) are considered a "program", licensed under
the terms of the GNU General Public License 3.0, which is provided in
the file gpl-3.0.txt.  If you distribute this program as part of a
derived work (including but not limited to use in an FPGA or ASIC),
the license imposes obligations on you to make the source code for the
entire work available.  No one forces you to accept this license, but
if you choose not to accept it, nothing authorizes you to redistribute
this program in any form.

If you wish to use this program as part of a derived work, but without
the obligations imposed by the GPL license, contact the author
regarding alternative licensing.
