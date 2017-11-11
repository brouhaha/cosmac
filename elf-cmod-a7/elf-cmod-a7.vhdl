-- COSMAC ELF top level for ELF-CMOD-A7
-- Copyright 2009, 2010, 2016, 2017 Eric Smith <spacewar@gmail.com>

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

--library unisim;
--use unisim.vcomponents.all;

entity elf_cmod_a7 is
  port (clk_in:        in  std_logic;
        reset_in:      in  std_logic;
        
        sw_d:          in  std_logic_vector (7 downto 0);
        sw_load_nc_n:  in  std_logic;
        sw_input_nc_n: in  std_logic;
        sw_mp_n:       in  std_logic;
        sw_run:        in  std_logic;
        
        led_q:         out std_logic;
        
        led_d:         out std_logic_vector (3 downto 0);

        led_a3_latch:  out std_logic;
        led_a2_latch:  out std_logic;
        led_a32_blank: out std_logic;

        led_a1_latch:  out std_logic;
        led_a0_latch:  out std_logic;
        led_a10_blank: out std_logic;

        led_dl_latch:  out std_logic;
        led_dh_latch:  out std_logic;
        led_d_blank:   out std_logic;
        
        uart_txd:      out std_logic;
        uart_rxd:      in  std_logic;
        uart_rts_n:    out std_logic;
        uart_cts_n:    in  std_logic;
        
        video:         out std_logic;
        csync_n:       out std_logic);
end elf_cmod_a7;

architecture rtl of elf_cmod_a7 is

  signal sys_clk:              std_logic;
  
  signal sys_clk_counter:      unsigned (7 downto 0);
  signal sys_clk_enable:       std_logic;
  
  signal reset_cntr:           unsigned (3 downto 0);
  signal sync_reset:           std_logic;  -- to elf
  
  signal sw_input:             std_logic;
  signal sw_load:              std_logic;
  signal sw_mp:                std_logic;

  -- elf_load and elf_run are sw_load and sw_run gated to 0 when reset is active
  signal elf_load:             std_logic;
  signal elf_run:              std_logic;

  signal elf_addr:             std_logic_vector (15 downto 0);
  signal elf_data:             std_logic_vector (7 downto 0);
  signal elf_q:                std_logic;

  signal video_clk_divider:    unsigned (4 downto 0);
  signal video_clk:            std_logic;

  signal fb_read_en:           std_logic;
  signal fb_addr:              std_logic_vector (9 downto 0);
  signal fb_data:              std_logic_vector (7 downto 0);

  signal csync:                std_logic;
  
begin

  sw_mp    <= not sw_mp_n;
  sw_input <= sw_input_nc_n;
  sw_load  <= sw_load_nc_n;
  
  
  ---- divide by 256 to run Elf at normal speed
  --scd: process (sys_clk)
  --begin
  --  if rising_edge (sys_clk) then
  --    if sys_clk_counter = 0 then
  --      sys_clk_enable <= '1';
  --    else
  --      sys_clk_enable <= '0';
  --    end if;
  --    sys_clk_counter <= sys_clk_counter + 1;
  --  end if;
  --end process;
  
  sys_clk_enable <= '1';
  

  clock_synth: entity work.clock_x7
    generic map (clk_in_freq => 12.0e6)
    port map (reset            => reset_in,
              clk_in           => clk_in,
              clk_out          => sys_clk,
              locked           => open);
              
  reset_p: process (sys_clk)
  begin
    if rising_edge (sys_clk) then
      if reset_in = '1' then
        sync_reset <= '1';
        reset_cntr <= to_unsigned(0, reset_cntr'length);
      else
        if reset_cntr = (reset_cntr'high downto reset_cntr'low => '1') then
          sync_reset <= '0';
        end if;
        reset_cntr <= reset_cntr + 1;
      end if;
    end if;
  end process reset_p;
                
  elf_run  <= '1' when sync_reset = '0' and sw_run = '1'
         else '0';
  elf_load <= '1' when sync_reset = '0' and sw_load = '1'
         else '0';
              
  hex_led_mux: entity work.hex_led_mux
           port map (clk           => sys_clk,
                     reset         => sync_reset,
                     data          => elf_data,
                     addr          => elf_addr,
                     led_d         => led_d,
                     led_a3_latch  => led_a3_latch,
                     led_a2_latch  => led_a2_latch,
                     led_a32_blank => led_a32_blank,
                     led_a1_latch  => led_a1_latch,
                     led_a0_latch  => led_a0_latch,
                     led_a10_blank => led_a10_blank,
                     led_dh_latch  => led_dh_latch,
                     led_dl_latch  => led_dl_latch,
                     led_d_blank   => led_d_blank);
         
  led_q <= elf_q;

  video_clk_divider_p: process (sys_clk)
  begin
    if rising_edge (sys_clk) then
      video_clk_divider <= video_clk_divider + 1;
    end if;
  end process video_clk_divider_p;
  video_clk <= video_clk_divider (video_clk_divider'left);

  elf_p: entity work.elf
    port map (clk         => sys_clk,
              clk_enable  => sys_clk_enable,
    
              sw_input    => sw_input,
              sw_load     => elf_load,
              sw_mp       => sw_mp,
              sw_run      => elf_run,
              sw_data     => sw_d,
              
              led_address => elf_addr,
              led_data    => elf_data,
              led_q       => elf_q,

              video_clk   => video_clk,
              csync       => csync,
              video       => video,
              
              rxd         => '1',
              txd         => open);

  csync_n <= not csync;
  
  uart_txd <= uart_rxd;
  uart_rts_n <= uart_cts_n;
              
end rtl;
