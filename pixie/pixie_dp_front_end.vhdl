-- PIXIE graphics core, front end, dual-port memory version
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

entity pixie_dp_front_end is
  port (clk:        in  std_logic;
        clk_enable: in  std_logic;
        reset:      in  std_logic;
        sc:         in  std_logic_vector (1 downto 0);
        disp_on:    in  std_logic;
        disp_off:   in  std_logic;
        data:       in  std_logic_vector (7 downto 0);

        dmao:       out std_logic;
        int:        out std_logic;
        efx:        out std_logic;

        mem_addr:   out std_logic_vector(9 downto 0);
        mem_data:   out std_logic_vector(7 downto 0);
        mem_wr_en:  out std_logic);
end pixie_dp_front_end;

architecture rtl of pixie_dp_front_end is

  constant bytes_per_line:  natural := 14;
  constant lines_per_frame: natural := 262;
  
  signal sc_fetch:             std_logic;
  signal sc_execute:           std_logic;
  signal sc_dma:               std_logic;
  signal sc_interrupt:         std_logic;

  signal enabled:              std_logic;

  signal horizontal_counter:   unsigned (3 downto 0);
  signal horizontal_end:       std_logic;
  
  signal vertical_counter:     unsigned (8 downto 0);
  signal vertical_end:         std_logic;

  signal v_active:             std_logic;

  signal dma_xfer:             std_logic;
  signal addr_counter:         unsigned (9 downto 0);

  
  function to_std_logic (b: boolean) return std_logic is
  begin
    if b then
      return '1';
    else
      return '0';
    end if;
  end function to_std_logic;

begin
  sc_fetch     <= to_std_logic (sc = "00");
  sc_execute   <= to_std_logic (sc = "01");
  sc_dma       <= to_std_logic (sc = "10");
  sc_interrupt <= to_std_logic (sc = "11");

  enable_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      if reset = '1' then
        enabled <= '0';
      elsif disp_on = '1' then
        enabled <= '1';
      elsif disp_off = '1' then
        enabled <= '0';
      end if;
    end if;
  end process;
  
  horizontal_end <= to_std_logic (horizontal_counter = (bytes_per_line - 1));

  hc_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      if horizontal_end = '1' then
        horizontal_counter <= to_unsigned (0, horizontal_counter'length);
        -- If sc_execute = '0', should skip one cycle to resync?  See
        -- description of SC0 and SC1 signals in CDP1861 datasheet,
        -- although the values described therein are wrong.
      else
        horizontal_counter <= horizontal_counter + 1;
      end if;
    end if;
  end process;

  vertical_end <= to_std_logic (vertical_counter = (lines_per_frame - 1));

  vc_p: process (clk, clk_enable, horizontal_end)
  begin
    if rising_edge (clk) and clk_enable = '1' and horizontal_end = '1' then
      if vertical_end = '1' then
        vertical_counter <= to_unsigned (0, vertical_counter'length);
      else
        vertical_counter <= vertical_counter + 1;
      end if;
      efx <= to_std_logic ((vertical_counter >= 76  and vertical_counter < 80) or
                           (vertical_counter >= 204 and vertical_counter < 208));
      int <= to_std_logic (enabled = '1' and
                           vertical_counter >= 78 and
                           vertical_counter < 80);
      v_active <= to_std_logic (enabled = '1' and
                                vertical_counter >= 80 and
                                vertical_counter < 208);
    end if;
  end process;

  dmao <= to_std_logic (enabled = '1' and
                        v_active = '1' and
                        horizontal_counter >= 1 and
                        horizontal_counter < 9);

  dma_xfer <= to_std_logic (enabled = '1' and
                            sc_dma = '1');

  ac_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      if reset = '1' or (horizontal_end = '1' and vertical_end = '1') then
        addr_counter <= to_unsigned (0, addr_counter'length);
      elsif dma_xfer = '1' then
        addr_counter <= addr_counter + 1;
      end if;
    end if;
  end process;

  mem_addr  <= std_logic_vector (addr_counter);
  mem_data  <= data;
  mem_wr_en <= dma_xfer;

end rtl;
