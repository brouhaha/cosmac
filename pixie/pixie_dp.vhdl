-- PIXIE graphics core, dual-port memory version
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


-- Pixie (CDP1861) graphics with composite video output, split between
-- a front end that runs from 1802 bus clock, and a back end that runs
-- at a video clock, separated by a dual-port RAM frame buffer.

-- Differences from CDP1861:
--   All bus timing is synchronous to rising edge of clk. No TPA or TPB signals
--   are used.

--   All signals are active high, unlike real hardware,
--   which has active low signals for:
--     inputs:  clk, reset
--     outputs: efx, int, dmao, efx, comp_sync

--   The dis_off signal is synchronous level-sensitive, unlike real hardware,
--   in which it is asynchronous and edge-triggered.

--   No clear output is provided; in CDP1861 it is the output of a
--   Schmitt trigger, with reset as the input.

library ieee;
use ieee.std_logic_1164.all;

entity pixie_dp is
  port (-- front end, CDP1802 bus clock domain
        clk:        in  std_logic;
        clk_enable: in  std_logic := '1';
        reset:      in  std_logic;
        sc:         in  std_logic_vector (1 downto 0);
        disp_on:    in  std_logic;
        disp_off:   in  std_logic;
        data:       in  std_logic_vector (7 downto 0);

        dmao:       out std_logic;
        int:        out std_logic;
        efx:        out std_logic;

        -- back end, video clock domain
        video_clk:  in  std_logic;

        csync:      out std_logic;
        video:      out std_logic);
end pixie_dp;

architecture rtl of pixie_dp is

  signal fb_a_addr: std_logic_vector (9 downto 0);
  signal fb_a_data: std_logic_vector (7 downto 0);
  signal fb_a_en:   std_logic;
  
  signal fb_a_en2:  std_logic;

  signal fb_b_addr: std_logic_vector (9 downto 0);
  signal fb_b_data: std_logic_vector (7 downto 0);
  signal fb_b_en:   std_logic;

begin

  fe: entity work.pixie_dp_front_end (rtl)
    port map (clk        => clk,
              clk_enable => clk_enable,
              reset      => reset,
              sc         => sc,
              disp_on    => disp_on,
              disp_off   => disp_off,
              data       => data,

              dmao       => dmao,
              int        => int,
              efx        => efx,

              mem_addr   => fb_a_addr,
              mem_data   => fb_a_data,
              mem_wr_en  => fb_a_en
              );
              
  fb_a_en2 <= clk_enable and fb_a_en;

  fb: entity work.pixie_dp_frame_buffer (rtl)
    port map (clk_a      => clk,
              en_a       => fb_a_en2,
              addr_a     => fb_a_addr,
              d_in_a     => fb_a_data,

              clk_b      => video_clk,
              en_b       => fb_b_en,
              addr_b     => fb_b_addr,
              d_out_b    => fb_b_data);

  be: entity work.pixie_dp_back_end (rtl)
    port map (clk        => video_clk,
              fb_read_en => fb_b_en,
              fb_addr    => fb_b_addr,
              fb_data    => fb_b_data,

              csync      => csync,
              video      => video);

  
end rtl;
