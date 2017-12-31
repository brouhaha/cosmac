-- Adder
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


entity adder is
  generic (width: natural);
  port (a_in:  in  unsigned (width - 1 downto 0);
        b_in:  in  unsigned (width - 1 downto 0);
        c_in:  in  std_logic;
        sum:   out unsigned (width - 1 downto 0);
        c_out: out std_logic);
end adder;

architecture rtl of adder is
  signal s: unsigned (width downto 0);

  function to_unsigned (b: std_logic; width: natural) return unsigned is
  begin
    if b = '1' then
      return to_unsigned (1, width);
    else
      return to_unsigned (0, width);
    end if;
  end;

begin
  s     <= ("0" & a_in) + ("0" & b_in) + to_unsigned (c_in, width + 1);
  sum   <= s (width - 1 downto 0);
  c_out <= s (width);
end rtl;


