-- PIXIE graphics core, frame buffer, dual-port memory version
-- Copyright 2017 Eric Smith <spacewar@gmail.com>

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of version 3 of the GNU General Public License
-- as published by the Free Software Foundation.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.


-- See comments in PIXIE top level source file, pixie_dp.vhdl

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pixie_dp_frame_buffer is
  port(
  clk_a:   in  std_logic;
  en_a:    in  std_logic;
  addr_a:  in  std_logic_vector(9 downto 0);
  d_in_a:  in  std_logic_vector(7 downto 0);

  clk_b:   in  std_logic;
  en_b:    in  std_logic;
  addr_b:  in  std_logic_vector(9 downto 0);
  d_out_b: out std_logic_vector(7 downto 0));
end pixie_dp_frame_buffer;

architecture rtl of pixie_dp_frame_buffer is
  type ram_t is array (0 to 1023) of std_logic_vector (7 downto 0);

  shared variable ram: ram_t;

begin
  process (clk_a, en_a)
  begin
  if rising_edge (clk_a) and en_a = '1' then
    ram (to_integer (unsigned (addr_a))) := d_in_a;
  end if;
  end process;

  process (clk_b, en_b)
  begin
  if rising_edge (clk_b) and en_b = '1' then
    d_out_b <= ram (to_integer (unsigned (addr_b)));
  end if;
  end process;
end architecture rtl;
