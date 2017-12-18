-- SPI master interface
-- Copyright 2017 Eric Smith <spacewar@gmail.com>
-- SPDX-License-Identifier: GPL-3.0

-- In the following licensing information, the term "program" includes but
-- is not limited to the provided VHDL source files and testbench stimulus
-- files, and any works derived therefrom, even if translated or compiled
-- into a different form and/or embedded in hardware.

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

entity spi_master is
  generic (brg_divisor_m1_width: natural := 8;
           data_width:           natural := 8;
           slave_count:          natural := 1);
  port (
    clk:                  in  std_logic;
    clk_enable:           in  std_logic := '1';  -- CPU bus clock enable only!
    reset:                in  std_logic;

    --====================
    -- SPI configuration
    --====================

    -- SPI
    -- Mode  CPOL  CPHA
    -- ----  ----  ----
    --   0     0     0
    --   1     0     1
    --   2     1     0
    --   3     1     1

    cpol:                 in  std_logic := '0';
    -- cpol = 0 for high pulses on SPI clock
    -- cpol = 1 for low pulses on SPI clock
    
    cpha:                 in  std_logic := '0';
    -- cpha = 0 - sample data on leading edge of SPI clock pulse,
    --            change output data on trailing edge of SPI clock pluse
    -- cpha = 1 - sample data on trailing edge of SPI clock pulse,
    --            change output data on leading edge of SPI clock pluse

    lsb_first:            in  std_logic := '0';
    -- lsb_first = 0 - normal MSB-first SPI transfers
    -- lsb_first = 1 - backwards SPI transfers, LSB first
    
    brg_divisor_m1:       in  unsigned (brg_divisor_m1_width - 1 downto 0);
    -- half-bit time is bit_divisor cycles of clk, minus one

    --====================
    -- processor interface
    --====================
    slave_id:             in  unsigned (log2ceil (slave_count) - 1 downto 0);
    -- if continuous is true, won't deassert slave select at end of transfer
    continuous:           in  std_logic;
    write_strobe:         in  std_logic;
    tx_data:              in  std_logic_vector (data_width - 1 downto 0);
    rx_data:              out std_logic_vector (data_width - 1 downto 0);
    done:                 out std_logic;

    --====================
    ---- SPI master serial interface
    --====================
    spi_slave_select:     out std_logic_vector (slave_count - 1 downto 0);
    spi_clk:              out std_logic;
    spi_mosi:             out std_logic;
    spi_miso:             in  std_logic
  );
end spi_master;


architecture rtl of spi_master is

  -- initializtion only needed for simulation
  signal brg_counter:  unsigned (brg_divisor_m1_width - 1 downto 0) := (others => '0');
  signal half_bit_clk: std_logic;

  signal slave_select: std_logic;

  signal sclk:         std_logic;
  signal prev_sclk:    std_logic;

  -- initialization only needed for simulation
  signal half_bit_counter: unsigned (log2ceil (data_width * 2) downto 0) := (others => '0');
  signal shift_reg:    std_logic_vector (data_width - 1 downto 0);

  -- Note that no dual-rank synchronizer is needed on the spi_miso
  -- input, because the SPI slave is only allowed to change the value
  -- of spi_miso on the opposite clock edge from the edge we sample
  -- on. If the SPI slave isn't following the protocol, all bets are
  -- off anyhow.

  signal mosi_r:       std_logic;  -- registered mosi, used when cpha = '1'
  signal miso_r:       std_logic;  -- registered miso, used when cpha = '0'

  signal sr_input:     std_logic;  -- muxed input to shift register
  signal sr_output:    std_logic;  -- muxed input to shift register

  signal done_b:       std_logic;

begin

  done <= done_b;

  brg_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) then
      if clk_enable = '1' and reset = '1' then
        brg_counter <= brg_divisor_m1;
        half_bit_clk <= '0';
      elsif brg_counter = 0 then
        brg_counter <= brg_divisor_m1;
        half_bit_clk <= '1';
      else
        brg_counter <= brg_counter - 1;
        half_bit_clk <= '0';
      end if;
    end if;
  end process brg_p;

  spi_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) then
      if clk_enable = '1' and reset = '1' then
        sclk <= '0';
        slave_select <= '0';
        half_bit_counter <= to_unsigned (0, half_bit_counter'length);
        done_b <= '1';
      elsif clk_enable = '1' and done_b = '1' and write_strobe = '1' then
        sclk <= '0';
        slave_select <= '1';
        half_bit_counter <= to_unsigned (2 * data_width + 1, half_bit_counter'length);
        done_b <= '0';
      elsif done_b = '0' and half_bit_clk = '1' then
        if half_bit_counter = 0 then
          slave_select <= continuous;
          done_b <= '1';
          sclk <= '0';
        elsif half_bit_counter = 1 then
          -- special case last half-bit time to get done and slave_select
          -- timing right
          sclk <= '0';
          half_bit_counter <= half_bit_counter - 1;
        else
          slave_select <= '1';
          half_bit_counter <= half_bit_counter - 1;
          done_b <= '0';
          sclk <= not sclk;
        end if;
      end if;
    end if;
  end process spi_p;

  ssp: process (slave_select, slave_id)
  begin
    spi_slave_select <= (others => '0');
    if slave_select = '1' then
      spi_slave_select (to_integer (slave_id)) <= '1';
    end if;
  end process ssp;

  sr_input <= miso_r when cpha = '0'
              else spi_miso;

  sr_output <= shift_reg (data_width - 1) when lsb_first = '0'
          else shift_reg (0);

  srp: process (clk)
  begin
    if rising_edge(clk) then
      if clk_enable = '1' and done_b = '1' and write_strobe = '1' then
        shift_reg <= tx_data;
      else
        if sclk = '1' and prev_sclk = '0' then
          miso_r <= spi_miso;
          mosi_r <= sr_output;
        end if;
        if sclk = '0' and prev_sclk = '1' then
          if lsb_first = '0' then
            shift_reg <= shift_reg (data_width - 2 downto 0) & sr_input;
          else
            shift_reg <= sr_input & shift_reg (data_width - 1 downto 1);
          end if;
        end if;
        prev_sclk <= sclk;
      end if;

      spi_clk <= sclk xor cpol;
    end if;
  end process srp;

  spi_mosi <= sr_output when cpha = '0'
              else mosi_r;

  rx_data <= shift_reg;

end rtl;
