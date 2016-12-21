-- 256x8 RAM for ELF
-- high byte of address ignored
-- Copyright 2009, 2010 Eric Smith <spacewar@gmail.com>

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

library unisim;
use unisim.vcomponents.all; 
entity elf_ram_256 is
  
  port (
    clk:         in  std_logic;
    address:     in  std_logic_vector (15 downto 0);
    mem_read:    in  std_logic;
    mem_write:   in  std_logic;
    data_in:     in  std_logic_vector (7 downto 0);
    data_out:    out std_logic_vector (7 downto 0)
  );

end elf_ram_256;

architecture rtl of elf_ram_256 is

  subtype byte_t is std_logic_vector (7 downto 0);

  signal ram_clk: std_logic;
  
  signal addr: std_logic_vector (10 downto 0);

begin

  ram_clk <= not clk;                   -- RAM clock is active on falling edge

  addr <= "000" & address (7 downto 0);
  
  ram0: RAMB16_S9
    generic map (
      INIT       => x"000",
      SRVAL      => x"000",
      write_mode => "WRITE_FIRST"
	 )
    port map (
      DO   => data_out,
      DOP  => open,
      ADDR => addr,
      CLK  => ram_clk,
      DI   => data_in,
      DIP  => "0",
      EN   => '1',
      SSR  => '0',
      WE   => mem_write);

end rtl;
