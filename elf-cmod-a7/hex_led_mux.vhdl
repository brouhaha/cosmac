-- ELF-CMOD-A7 hexadecimal LED multiplexer
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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hex_led_mux is
  port (clk:           in  std_logic;
        reset:         in  std_logic;
    
        data:          in  std_logic_vector (7 downto 0);
        addr:          in  std_logic_vector (15 downto 0);
  
        led_d:         out std_logic_vector (3 downto 0);
        led_dl_latch:  out std_logic;
        led_dh_latch:  out std_logic;
        led_d_blank:   out std_logic;
        led_a3_latch:  out std_logic;
        led_a2_latch:  out std_logic;
        led_a1_latch:  out std_logic;
        led_a0_latch:  out std_logic;
        led_a32_blank: out std_logic;
        led_a10_blank: out std_logic);
end hex_led_mux;

architecture rtl of hex_led_mux is

  signal clock_divider: unsigned (1 downto 0);
  signal clk_en: std_logic;

  type state_t is (state_idle,
                   state_start,
                   state_set_data,
                   state_pulse,
                   state_wait);
                   
  signal state: state_t;
  signal next_state: state_t;
  
  signal mux_counter: unsigned (2 downto 0);

  signal prev_data: std_logic_vector (7 downto 0);
  signal prev_addr: std_logic_vector (15 downto 0);
 
  function to_std_logic (b: boolean) return std_logic is
  begin
    if b then
      return '1';
    else
      return '0';
    end if;
  end function to_std_logic;

begin
  process (clk)
  begin
    if rising_edge (clk) then
      clock_divider <= clock_divider + 1;
    end if;
  end process;
  clk_en <= to_std_logic (clock_divider = 0);
  
  process (clk, clk_en)
  begin
    if rising_edge (clk) and clk_en = '1' then
      if reset = '1' then
        state <= state_start;
        mux_counter <= to_unsigned (0, mux_counter'length);
      else
        state <= next_state;
        if state = state_start then
          prev_data <= data;
          prev_addr <= addr;
          mux_counter <= to_unsigned (6, mux_counter'length);
        elsif state = state_wait and mux_counter /= 0 then
          mux_counter <= mux_counter - 1;
        end if;
      end if;
    end if;
  end process;
  
  next_state <= state_start    when state = state_idle and (addr /= prev_addr or data /= prev_data)
           else state_set_data when state = state_start or (state = state_wait and mux_counter /= 0)
           else state_pulse    when state = state_set_data
           else state_wait     when state = state_pulse
           else state_idle;
  
  led_d <= prev_addr (15 downto 12) when mux_counter = 6
      else prev_addr (11 downto  8) when mux_counter = 5
      else prev_addr ( 7 downto  4) when mux_counter = 4
      else prev_addr ( 3 downto  0) when mux_counter = 3
      else prev_data ( 7 downto  4) when mux_counter = 2
      else prev_data ( 3 downto  0) when mux_counter = 1
      else "0000"; 
      
  led_a3_latch <= '0' when state = state_pulse and mux_counter = 6
             else '1';
  led_a2_latch <= '0' when state = state_pulse and mux_counter = 5
             else '1';
  led_a1_latch <= '0' when state = state_pulse and mux_counter = 4
             else '1';
  led_a0_latch <= '0' when state = state_pulse and mux_counter = 3
             else '1';
  led_dh_latch <= '0' when state = state_pulse and mux_counter = 2
             else '1';
  led_dl_latch <= '0' when state = state_pulse and mux_counter = 1
             else '1';
  
  led_d_blank   <= '0';
  led_a32_blank <= '0';
  led_a10_blank <= '0';
  
end architecture rtl;
