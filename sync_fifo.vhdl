-- Synchronous FIFO
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
use work.util.all;

entity sync_fifo is
  generic (data_width: natural := 8;
           depth:      natural := 16);
  port (
    clk:            in  std_logic;
    clk_enable:     in  std_logic;
    reset:          in  std_logic;

    write_enable:   in  std_logic;
    write_data:     in  std_logic_vector (data_width - 1 downto 0);

    read_enable:    in  std_logic;
    read_data:      out std_logic_vector (data_width - 1 downto 0);

    threshold:      in  unsigned (log2ceil (depth) - 1 downto 0) := to_unsigned (depth / 2, log2ceil (depth));
    
    empty:          out std_logic;
    over_threshold: out std_logic;
    full:           out std_logic
  );
end sync_fifo;

architecture rtl of sync_fifo is

  constant address_width: natural := log2ceil (depth);

  type ram_t is array (0 to depth - 1) of std_logic_vector (data_width - 1 downto 0);

  signal ram: ram_t;

  signal gated_write_enable: std_logic;
  signal write_ptr:  unsigned (address_width - 1 downto 0);

  signal gated_read_enable: std_logic;
  signal read_ptr:   unsigned (address_width - 1 downto 0);

  signal level:      unsigned (address_width downto 0);

  function to_std_logic (b: boolean) return std_logic is
  begin
    if b then
      return '1';
    else
      return '0';
    end if;
  end function to_std_logic;

begin

  gated_write_enable <= write_enable and to_std_logic (level /= depth);

  write_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      if reset = '1' then
        write_ptr <= to_unsigned (0, write_ptr'length);
      elsif gated_write_enable = '1' then
        ram (to_integer (write_ptr)) <= write_data;
        write_ptr <= write_ptr + 1;     
      end if;
    end if;
  end process write_p;

  gated_read_enable <= read_enable and to_std_logic (level /= 0);

  read_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      if reset = '1' then
        read_ptr <= to_unsigned (0, read_ptr'length);
      elsif gated_read_enable = '1' then
        read_ptr <= read_ptr + 1;
      end if;
    end if;
  end process read_p;

  level_p: process (clK, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      if reset = '1' then
        level <= to_unsigned (0, level'length);
      elsif gated_write_enable = '1' and gated_read_enable = '0' then
        level <= level + 1;
      elsif gated_write_enable = '0' and gated_read_enable = '1' then
        level <= level - 1;
      end if;
    end if;  
  end process level_p;  

  read_data <= ram (to_integer (read_ptr));

  empty <= '1' when level = 0
      else '0';

  full <= '1' when level = depth
     else '0';

  over_threshold <= '1' when level >= threshold
               else '0';

end rtl;
