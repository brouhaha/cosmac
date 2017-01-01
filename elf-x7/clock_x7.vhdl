-- Xilinx 7-series FPGA clock synthesizer
-- Copyright 2017 Eric Smith <spacewar@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity clock_x7 is
  generic (clk_in_freq: real := 100.0e6);
  port (reset:   in  std_logic;
        clk_in:  in  std_logic;
        clk_out: out std_logic;
        locked:  out std_logic);
end clock_x7;

architecture rtl of clock_x7 is
  constant clk_in_period_ns: real := 1.0e9 / clk_in_freq;
  signal clkfb: std_logic;
begin

  -- For information on Xilinx MMCME2_BASE and BUFG primitives, see:
  -- Xilinx UG472: 7 Series FPGAs Clocking Resources User Guide
  -- Xilinx UG593: Vivado Design Suite 7 Series FPGA [...] Libraries Guide

  -- For MMCME2 timing requirements, see:
  -- Xilinx DS181: Artix-7 FPGAs Data Sheet: DC and AC Switching Characteristics
  -- Xilinx DS182: Kintex-7 FPGAs Data Sheet: DC and AC Switching Characteristics
  -- Xilinx DS183: Virtex-7 T and XT FPGAs Data Sheet: DC and AC Switching Characteristics
  -- Xilinx DS189: Spartan-7 FPGAs Data Sheet: DC and AC Switching Characteristics

  -- Timing requirements for Artix 7 -1 speed grade:
  --                min      max   unit
  --               ------  ------  ----
  -- f(clkin1)      10.0    800.0  MHz
  -- f(pfd)         10.0    450.0  Mhz
  -- f(vco)        600.0   1200.0  MHz
  -- f(clkout0)      4.69   800.0  MHz

  -- f(clkfb)   = f(clkin1) / divclk_divide
  -- f(vco)     = f(clkfb) * clkfbout_mult_f
  -- f(clkout0) = f_vco / clkout0_divide_f

  clock_manager: mmcme2_base
    generic map (clkin1_period    => clk_in_period_ns,
                 divclk_divide    => 1,     -- integer 1 to 106
                 clkfbout_mult_f  => 10.0,  -- integer 2 to 64 or
                                            -- real 2.000 to 64.000 in
                                            -- increments of 0.125
                 clkout0_divide_f => 16.0,  -- integer 1 to 128 or
                                            -- real 2.000 to 128.000 in
                                            -- increments of 0.125
                 startup_wait     => true)
    port map (clkin1   => clk_in,
              clkfbin  => clkfb,
              rst      => reset,
              pwrdwn   => '0',

              clkout0  => clk_out,
              clkout1  => open,
              clkout2  => open,
              clkout3  => open,
              clkout4  => open,
              clkout5  => open,
              clkfbout => clkfb,
              locked   => locked);
   
end rtl;
