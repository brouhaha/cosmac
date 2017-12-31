-- Utility functions
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package util is

  function to_std_logic (b: boolean) return std_logic;

  function log2ceil (l: positive) return natural;
  function log2floor (l: positive) return natural;
  function srl_integer (arg: integer; s: natural) return integer;

end package util;

package body util is 

  function to_std_logic (b: boolean) return std_logic is
  begin
    if b then
      return '1';
    else
      return '0';
    end if;
  end function to_std_logic;

  -- log2ceil, log2floor, srl_integer by Karsten Becker,
  -- to avoid any possible rounding error from using
  -- ieee.math_real.log2
  function log2ceil (l: positive) return natural is
    variable i, bit_count : natural;
  begin
    i := l - 1;
    bit_count := 0;
    while (i > 0) loop
      bit_count := bit_count + 1;
      i := srl_integer (i, 1);
    end loop;
    return bit_count;
  end log2ceil;

  function log2floor (l: positive) return natural is
    variable i, bit_count : natural;
  begin
    i := l;
    bit_count:=0;
    while (i > 1) loop
      bit_count := bit_count + 1;
      i := srl_integer (i, 1);
    end loop;
    return bit_count;
  end log2floor;

  function srl_integer (arg: integer; s: natural) return integer is
  begin
    return to_integer (shift_right (to_unsigned (ARG,32), s));
  end srl_integer;

end package body util;
