-- switch debouncer for Elf
-- Copyright 2009 Eric Smith <spacewar@gmail.com>

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

entity debouncer is
  generic (
    log2_counter_width: integer := 4;
    max_count: integer := 15
  );
  port (
    clk:         in  std_logic;
    raw_sw:      in  std_logic;
    deb_sw:      out std_logic
  );

end debouncer;

architecture rtl of debouncer is

  signal state:  std_logic;
  signal counter : unsigned (log2_counter_width - 1 downto 0) := "0000";

begin

  deb_sw <= state;

  debounce_p: process (clk)
  begin
    if rising_edge (clk) then
      if raw_sw = state then
        counter <= (others => '0');
      elsif counter = max_count then
        state <= raw_sw;
        counter <= (others => '0');
      else
        counter <= counter + 1;
      end if;
    end if;
  end process debounce_p;

end rtl;
