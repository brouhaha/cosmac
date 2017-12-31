-- Fractional clock divisor, pulse output
-- Copyright 2017 Eric Smith <spacewar@gmail.com>
-- SPDX-License-Identifier: GPL-3.0

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of version 3 of the GNU General Public License
-- as published by the Free Software Foundation.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.


-- The fractional clock divider operates in the same manner as a
-- fractional-N synthesizer, using a dual-modulus prescaler.  The
-- divisor is selected between integer N and N+1 on a per-cycle basis,
-- such that the average is the fractional N desired.  The fractional
-- part of N is added to an accumulator on every cycle, and the N+1
-- modulus is chosen for cycles in which the fraction accumulator
-- overflows, to distribute the N+1 cycles as evenly as possible.

-- Note that the integer portion of the divisor is provided to the divider
-- as the input signal divisor_m1_integer, in the form of the integer part
-- minus one, e.g., for a divisor of 3.75, the divsior_m1_integer value
-- is 2, and the fraction, in binary, is 110...

-- This divider does not attempt to provide a 50% duty cycle, or even an
-- approximation of that. It provides one output pulse per output cycle,
-- with the width of the pulse being one input clock cycle.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity fractional_clock_divider is
  generic (divisor_integer_width:  natural := 16;
           divisor_fraction_width: natural := 8);
  port (
    clk_in:               in  std_logic;
    reset:                in  std_logic;
    divisor_m1_integer:   in  unsigned (divisor_integer_width - 1 downto 0);
    divisor_fraction:     in  unsigned (divisor_fraction_width - 1 downto 0);
    clk_out:              out std_logic);
end fractional_clock_divider;

architecture rtl of fractional_clock_divider is

  signal int_counter: unsigned (divisor_integer_width - 1 downto 0);
  signal frac_accum:  unsigned (divisor_fraction_width - 1 downto 0);

  signal frac_sum:      unsigned (divisor_fraction_width - 1 downto 0);
  signal frac_overflow: std_logic;

begin

  frac_addr: entity work.adder (rtl)
    generic map (width => divisor_fraction_width)
    port map (a_in  => frac_accum,
              b_in  => divisor_fraction,
              c_in  => '0',
              sum   => frac_sum,
              c_out => frac_overflow);

  int_p: process (clk_in)
  begin
    if rising_edge (clk_in) then
      if reset = '1' then
        int_counter <= divisor_m1_integer;
        frac_accum  <= to_unsigned (0, frac_accum'length);
        clk_out <= '0';
      elsif int_counter = 0 then
        if frac_overflow = '1' then
          int_counter <= divisor_m1_integer + 1;
        else
          int_counter <= divisor_m1_integer;
        end if;
        frac_accum <= frac_sum;
        clk_out <= '1';
      else
        int_counter <= int_counter - 1;
        clk_out <= '0';
      end if;
    end if;
  end process int_p;

end rtl;
