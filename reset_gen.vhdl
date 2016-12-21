-- reset generator for 1802 test
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

entity reset_gen is
  
  port (
    clk:         in  std_logic;
    ext_reset:   in  std_logic;
    reset:       out std_logic
  );

end reset_gen;

architecture rtl of reset_gen is

  signal ext_reset_sync1 : std_logic;
  signal ext_reset_sync2 : std_logic;

  signal int_reset: std_logic := '1';
  signal counter : unsigned (3 downto 0) := "0000";

begin

  reset <= int_reset or ext_reset_sync2;

  reset_p: process (clk)
  begin
    if rising_edge (clk) then
      ext_reset_sync1 <= ext_reset;
      ext_reset_sync2 <= ext_reset_sync1;
      if ext_reset_sync2 = '1' then
        counter <= "0000";
      elsif counter (3) = '1' then
        int_reset <= '0';
      else
        counter <= counter + 1;
      end if;
    end if;
  end process reset_p;

end rtl;
