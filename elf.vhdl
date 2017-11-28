-- COSMAC ELF system
-- Copyright 2009, 2016, 2017 Eric Smith <spacewar@gmail.com
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

entity elf is
  generic (clk_freq:      real := 25.0e6;
           debounce_time: time := 1 ms;
           uart_rate:     real := 19200.0);
  port (clk:             in     std_logic;
        clk_enable:      in     std_logic := '1';
        
        limit_256_bytes: in     std_logic := '0';

        sw_input:        in     std_logic;
        sw_load:         in     std_logic;
        sw_mp:           in     std_logic;
        sw_run:          in     std_logic;

        sw_data:         in     std_logic_vector(7 downto 0);

        led_address:     out    std_logic_vector(15 downto 0);
        led_data:        out    std_logic_vector(7 downto 0);
        led_q:           out    std_logic;

        video_clk:       in     std_logic;
        csync:           out    std_logic;
        video:           out    std_logic;

        rxd:             in     std_logic;
        rtr:             out    std_logic; -- Ready to Receive (same pin as RTS)
        txd:             out    std_logic;
        cts:             in     std_logic);

end elf;

architecture rtl of elf is

  constant pixie_port:         std_logic_vector (2 downto 0) := "001";
  constant switch_led_port:    std_logic_vector (2 downto 0) := "100";
  constant uart_port:          std_logic_vector (2 downto 0) := "111";

  signal pixie_selected:       std_logic;
  signal switch_led_selected:  std_logic;
  signal uart_selected:        std_logic;

  signal deb_sw_input:         std_logic;
  signal deb_sw_load:          std_logic;
  signal deb_sw_mp:            std_logic;
  signal deb_sw_run:           std_logic;

  signal delayed_deb_sw_input: std_logic;

  signal dma_in_req:           std_logic;
  signal dma_out_req:          std_logic;
  signal clear_req:            std_logic;
  signal int_req:              std_logic;
  signal wait_req:             std_logic;

  signal ef:                   std_logic_vector (4 downto 1);

  signal data_bus:             std_logic_vector (7 downto 0);
  
  signal proc_data_out:        std_logic_vector (7 downto 0);
  
  signal address:              std_logic_vector (15 downto 0);
  signal mem_read:             std_logic;
  signal mem_write:            std_logic;
  signal mem_write_gated:      std_logic;
  signal io_port:              std_logic_vector (2 downto 0);
  signal q_out:                std_logic;
  signal sc:                   std_logic_vector (1 downto 0);

  signal led_data_out:         std_logic_vector (7 downto 0);

  signal mem_read_data:        std_logic_vector (7 downto 0);
  
  signal pixie_disp_on:        std_logic;
  signal pixie_disp_off:       std_logic;
  signal pixie_efx:            std_logic;
  
  signal uart_reset:           std_logic;
  signal uart_rx_buf_empty:    std_logic;
  signal uart_read_rx:         std_logic;
  signal uart_read_data:       std_logic_vector (7 downto 0);
  signal uart_tx_buf_full:     std_logic;
  signal uart_write_tx:        std_logic;
  
begin

  sw_input_debouncer: entity work.debouncer (rtl)
    --generic map (clk_freq =>      clk_freq,
    --             debounce_time => debounce_time)
    port map (clk    => clk,
              clk_en => clk_enable,
              raw_sw => sw_input,
              deb_sw => deb_sw_input);

  sw_load_debouncer: entity work.debouncer (rtl)
    --generic map (clk_freq =>      clk_freq,
    --             debounce_time => debounce_time)
    port map (clk    => clk,
              clk_en => clk_enable,
              raw_sw => sw_load,
              deb_sw => deb_sw_load);

  sw_mp_debouncer: entity work.debouncer (rtl)
    --generic map (clk_freq =>      clk_freq,
    --             debounce_time => debounce_time)
    port map (clk    => clk,
              clk_en => clk_enable,
              raw_sw => sw_mp,
              deb_sw => deb_sw_mp);

  sw_run_debouncer: entity work.debouncer (rtl)
    --generic map (clk_freq =>      clk_freq,
    --             debounce_time => debounce_time)
    port map (clk    => clk,
              clk_en => clk_enable,
              raw_sw => sw_run,
              deb_sw => deb_sw_run);


  led_address   <= address;
  led_data      <= led_data_out;
  led_q         <= q_out;

  clear_req     <= not sw_run;
  wait_req      <= sw_load;
  
  data_led_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      if (deb_sw_run = '0') and (deb_sw_load = '1') and (mem_read <= '1') then
        -- load mode, all memory reads
        led_data_out <= mem_read_data;
      elsif switch_led_selected = '1' and (mem_read <= '1') then
        -- out instruction
        led_data_out <= mem_read_data;
      end if;
    end if;
  end process;

  -- In LOAD mode, each press of INPUT switch only generates one DMA request
  -- XXX should clear dma_in_req based on (sc = sc_dma) and mem_write
  dma_in_req_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      delayed_deb_sw_input <= deb_sw_input;
      if dma_in_req = '0' then
        if deb_sw_run = '0' and deb_sw_load = '1' and delayed_deb_sw_input = '0' and deb_sw_input = '1' then
          dma_in_req <= '1';
        end if;
      else
        dma_in_req <= '0';
      end if;
    end if;
  end process;
    
  ef (1)        <= pixie_efx;
  ef (2)        <= not uart_tx_buf_full;  -- room for at least one tx char
  ef (3)        <= not uart_rx_buf_empty; -- at least one rx char avail
  ef (4)        <= deb_sw_input;

  processor: entity work.cosmac (rtl)
             port map (clk         => clk,
                       clk_enable  => clk_enable,
                       clear       => clear_req,
                       dma_in_req  => dma_in_req,
                       dma_out_req => dma_out_req,
                       int_req     => int_req,
                       wait_req    => wait_req,

                       ef          => ef,

                       data_in     => data_bus,
                       data_out    => proc_data_out,
                       address     => address,
                       mem_read    => mem_read,
                       mem_write   => mem_write,
                       io_port     => io_port,
                       q_out       => q_out,
                       sc          => sc);
                       
  pixie_selected      <= to_std_logic (io_port = pixie_port);
  switch_led_selected <= to_std_logic (io_port = switch_led_port);
  uart_selected       <= to_std_logic (io_port = uart_port);
                       
  data_bus <= mem_read_data  when mem_read = '1'
         else sw_data        when wait_req = '1'
         else sw_data        when mem_write = '1' and switch_led_selected = '1'   
         else uart_read_data when mem_write = '1' and uart_read_rx = '1'
         else proc_data_out  when mem_write = '1'
         else X"00";

  mem_write_gated <= mem_write and not deb_sw_mp;
  
  memory: entity work.memory (rtl)
    port map (limit_256_bytes => limit_256_bytes,
              clk             => clk,
              clk_enable      => clk_enable,
              address         => address,
              mem_read        => mem_read,
              mem_write       => mem_write_gated,
              data_in         => data_bus,
              data_out        => mem_read_data);

  pixie_disp_on       <= pixie_selected and mem_write;
  pixie_disp_off      <= pixie_selected and mem_read;

  pixie: entity work.pixie_dp (rtl)
    port map (clk        => clk,
              clk_enable => clk_enable,
              reset      => clear_req,
              sc         => sc,
              disp_on    => pixie_disp_on,
              disp_off   => '0',
              data       => data_bus,

              dmao       => dma_out_req,
              int        => int_req,
              efx        => pixie_efx,

              video_clk  => video_clk,

              csync      => csync,
              video      => video);

  uart_reset    <= not deb_sw_run;
  uart_read_rx  <= uart_selected and mem_write;
  uart_write_tx <= uart_selected and mem_read;

  uart: entity work.uart (rtl)
    port map (clk                  => clk,
              clk_enable           => clk_enable,
              reset                => uart_reset,
              rtr_handshake_enable => '1',
              cts_handshake_enable => '1',
              brg_divisor          => to_unsigned (367, 16),

              rx_buf_empty         => uart_rx_buf_empty,
              rx_buf_full          => open,
              read_rx              => uart_read_rx,
              rx_data              => uart_read_data,

              tx_buf_empty         => open,
              tx_buf_full          => uart_tx_buf_full,
              write_tx             => uart_write_tx,
              tx_data              => data_bus,

              rxd                  => rxd,
              rtr                  => rtr, -- Ready to Receive (same pin as RTS)
              txd                  => txd,
              cts                  => cts);

end rtl;
