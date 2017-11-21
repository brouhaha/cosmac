-- Simple UART
-- Copyright 2009, 2016, 2017 Eric Smith <spacewar@gmail.com>
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


-- This UART only implements 8N1 mode (8 start bits, no parity, 1 stop bit).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util.all;

entity uart is
  generic (brg_divisor_width: natural := 16;
           rx_fifo_depth:     natural := 16;
           tx_fifo_depth:     natural := 16);
  port (
    clk:                  in  std_logic;
    clk_enable:           in  std_logic := '1';
    reset:                in  std_logic;

    rtr_handshake_enable: in  std_logic := '0';
    rtr_threshold:        in  unsigned (log2ceil (rx_fifo_depth) - 1 downto 0) := to_unsigned (rx_fifo_depth / 2, log2ceil (rx_fifo_depth));
    
    cts_handshake_enable: in  std_logic := '0';

    brg_divisor:          in  unsigned (brg_divisor_width - 1 downto 0);

    -- processor interface
    rx_buf_empty:         out std_logic;  -- don't read if empty
    rx_buf_full:          out std_logic;
    read_rx:              in  std_logic;
    rx_data:              out std_logic_vector (7 downto 0);

    tx_buf_empty:         out std_logic;
    tx_buf_full:          out std_logic;  -- don't write if full
    write_tx:             in  std_logic;
    tx_data:              in  std_logic_vector (7 downto 0);

    -- serial interface
    rxd:                  in  std_logic;
    rtr:                  out std_logic;  -- Ready to Receive (same pin as RTS)

    txd:                  out std_logic;
    cts:                  in  std_logic := '1'   -- Clear to Send
  );
end uart;

architecture rtl of uart is

  signal brg_counter:    unsigned (brg_divisor_width - 1 downto 0);
  signal tx_16x_counter: unsigned (3 downto 0);
  signal rx_16x_counter: unsigned (3 downto 0);

  signal uart_clk_16x:   std_logic;
  signal uart_clk_1x:    std_logic;

  signal tx_reg: std_logic_vector (7 downto 0);

  signal rx_reg: std_logic_vector (7 downto 0);

  signal tx_state: unsigned (3 downto 0);
  constant tx_state_data_lsb: unsigned (3 downto 0) := "1001";
  -- data bits are 9 through 2
  constant tx_state_stop:     unsigned (3 downto 0) := "0001";
  constant tx_state_idle:     unsigned (3 downto 0) := "0000";

  signal rx_state: unsigned (3 downto 0);
  constant rx_state_start: unsigned (3 downto 0) := "1010";
  -- data bits are 9 through 2
  constant rx_state_stop:  unsigned (3 downto 0) := "0001";
  constant rx_state_idle:  unsigned (3 downto 0) := "0000";

  signal rx_fifo_write_enable:   std_logic;
  signal rx_fifo_empty:          std_logic;
  signal rx_fifo_over_threshold: std_logic;
  signal rx_fifo_full:           std_logic;

  signal tx_fifo_read_enable:    std_logic;
  signal tx_fifo_read_data:      std_logic_vector (7 downto 0);
  signal tx_fifo_empty:          std_logic;
  signal tx_fifo_full:           std_logic;

begin

  rx_fifo: entity work.sync_fifo (rtl)
    generic map (depth => rx_fifo_depth)
    port map (clk            => clk,
              clk_enable     => clk_enable,
              reset          => reset,
              write_enable   => rx_fifo_write_enable,
              write_data     => rx_reg,
              read_enable    => read_rx,
              read_data      => rx_data,
              threshold      => rtr_threshold,
              empty          => rx_fifo_empty,
              over_threshold => rx_fifo_over_threshold,
              full           => rx_fifo_full);

  rx_buf_empty <= rx_fifo_empty;
  rx_buf_full  <= rx_fifo_full;

  tx_fifo: entity work.sync_fifo (rtl)
    generic map (depth => tx_fifo_depth)
    port map (clk            => clk,
              clk_enable     => clk_enable,
              reset          => reset,
              write_enable   => write_tx,
              write_data     => tx_data,
              read_enable    => tx_fifo_read_enable,
              read_data      => tx_fifo_read_data,
              empty          => tx_fifo_empty,
              over_threshold => open,
              full           => tx_fifo_full);
              
  tx_buf_empty <= tx_fifo_empty;
  tx_buf_full  <= tx_fifo_full;

  brg_16x_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      if reset = '1' then
        brg_counter <= brg_divisor;
        uart_clk_16x <= '1';
      elsif to_integer (brg_counter) = 0 then
        brg_counter <= brg_divisor;
        uart_clk_16x <= '1';
      else
        brg_counter <= brg_counter - 1;
        uart_clk_16x <= '0';
      end if;
    end if;
  end process brg_16x_p;

  tx_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      tx_fifo_read_enable <= '0';
      if reset = '1' then
        tx_16x_counter <= "0000";
        tx_state <= tx_state_idle;
        txd <= '1';
      elsif uart_clk_16x = '1' then
        tx_16x_counter <= tx_16x_counter + 1;
        if tx_16x_counter = "0000" then
          if tx_state = tx_state_idle then
            if tx_fifo_empty = '0' and (cts = '1' or cts_handshake_enable = '0') then
              tx_reg <= tx_fifo_read_data;
              tx_fifo_read_enable <= '1';
              txd <= '0';
              tx_state <= tx_state_data_lsb;
            else
              txd <= '1';
            end if;
          else
            txd <= tx_reg (0);
            tx_reg <= '1' & tx_reg (7 downto 1);  -- The first one or two '1' bits shifted in will be stop bits
            tx_state <= tx_state - 1;
          end if;
        end if;
      end if;
    end if;
  end process tx_p;

  rx_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      rx_fifo_write_enable <= '0';
      if reset = '1' then
        rx_16x_counter <= "0000";
        rx_state <= rx_state_idle;
      else
        if uart_clk_16x = '1' then
          if rx_state = rx_state_idle then
            if rxd = '0' then
              rx_state <= rx_state_start;
              rx_16x_counter <= "0000";
            end if;
          else
            rx_16x_counter <= rx_16x_counter + 1;
            if rx_16x_counter = ("1000") then  -- sample bits in middle of cell
              if rx_state = rx_state_start then
                if rxd = '1' then
                  rx_state <= rx_state_idle;  -- false start bit
                else
                  rx_state <= rx_state - 1;
                end if;
              elsif rx_state = rx_state_stop then
                if rxd = '0' then
                  rx_state <= rx_state_idle;  -- framing error (ignore)
                else
                  -- could check for rx fifo overrun here
                  rx_fifo_write_enable <= '1';
                  rx_state <= rx_state - 1;
                end if;
              else
                rx_reg <= rxd & rx_reg (7 downto 1);
                rx_state <= rx_state - 1;
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process rx_p;

  rtr <= '0' when (rtr_handshake_enable = '1' and
                   rx_fifo_over_threshold = '1')
    else '1'; 

end rtl;
