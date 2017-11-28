-- PIXIE graphics core, back end, dual-port memory version
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


-- See comments in PIXIE top level source file, pixie_dp.vhdl

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util.all;

entity pixie_dp_back_end is
  port(clk:        in  std_logic;  -- should be around 1.76064 MHz (60 frames/s * 262 lines/frame * 14 bytes/line * 8 bits/byte)
       fb_read_en: out std_logic;
       fb_addr:    out std_logic_vector (9 downto 0);
       fb_data:    in  std_logic_vector (7 downto 0);
       csync:      out std_logic;
       video:      out std_logic);
end pixie_dp_back_end;

architecture rtl of pixie_dp_back_end is

  constant pixels_per_line:      natural := 112;
  constant active_h_pixels:      natural := 64;
  constant hsync_start_pixel:    natural := 82;  -- two cycles later to account for pipeline delay
  constant hsync_width_pixels:   natural := 12;

  constant lines_per_frame:      natural := 262;
  constant active_v_lines:       natural := 128;
  constant vsync_start_line:     natural := 182;
  constant vsync_height_lines:   natural := 16;

  signal load_pixel_shift_reg:   std_logic;
  signal pixel_shift_reg:        std_logic_vector (7 downto 0);
  
  signal horizontal_counter:     unsigned (7 downto 0);
  signal hsync:                  std_logic;
  signal active_h_adv2:          std_logic;  -- pipeline delay
  signal active_h_adv1:          std_logic;  -- pipeline delay
  signal active_h:               std_logic;
  signal advance_v:              std_logic;
    
  signal vertical_counter:       unsigned (8 downto 0);
  signal vsync:                  std_logic;
  signal active_v:               std_logic;
  
  signal active_video:           std_logic;

begin
  fb_addr (9 downto 3) <= std_logic_vector (vertical_counter (6 downto 0));
  fb_addr (2 downto 0) <= std_logic_vector (horizontal_counter (5 downto 3));
            
  horizontal_counter_p: process (clk)
    variable new_h: unsigned (horizontal_counter'range);
  begin
    if rising_edge (clk) then
      if horizontal_counter = (pixels_per_line - 1) then
        new_h := to_unsigned (0, horizontal_counter'length);
      else
        new_h := horizontal_counter + 1;
      end if;
      horizontal_counter <= new_h;
      fb_read_en <= to_std_logic (new_h (2 downto 0) = "000");
      load_pixel_shift_reg <= to_std_logic (new_h (2 downto 0) = "001");
      active_h_adv2 <= to_std_logic (new_h < active_h_pixels);
      active_h_adv1 <= active_h_adv2;
      active_h      <= active_h_adv1;
      hsync <= to_std_logic (new_h >= hsync_start_pixel and new_h < hsync_start_pixel + hsync_width_pixels);
      advance_v <= to_std_logic (new_h = (pixels_per_line - 1));
    end if;
  end process horizontal_counter_p;

  vertical_counter_p: process (clk, advance_v)
    variable new_v: unsigned (vertical_counter'range);
  begin
    if rising_edge (clk) and advance_v = '1' then
      if vertical_counter = (lines_per_frame - 1) then
        new_v := to_unsigned (0, vertical_counter'length);
      else
        new_v := vertical_counter + 1;
      end if;
      vertical_counter <= new_v;
      active_v <= to_std_logic (new_v < active_v_lines);
      vsync <= to_std_logic (new_v >= vsync_start_line and new_v < vsync_start_line + vsync_height_lines);
    end if;
  end process vertical_counter_p;

  csync <= hsync xor vsync;

  active_video <= active_h and active_v;

  pixel_shifter_p: process (clk)
  begin
    if rising_edge(clk) then
      if load_pixel_shift_reg = '1' then
        pixel_shift_reg <= fb_data;
      else
        pixel_shift_reg <= pixel_shift_reg (6 downto 0) & '0';
      end if;
      video <= active_video and pixel_shift_reg (7);
    end if; 
  end process pixel_shifter_p;

end architecture rtl;

