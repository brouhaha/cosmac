# COSMAC ELF system for Digilent Cmod-A7 module
# Copyright 2017 Eric Smith <spacewar@gmail.com
# SPDX-License-Identifier: GPL-3.0

# This program is free software: you can redistribute it and/or modify
# it under the terms of version 3 of the GNU General Public License
# as published by the Free Software Foundation.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

# Digilent Cmod-A7 on-board resources
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports clk_in]
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports reset_in]

# ELF-CMOD-A7 board resources
set_property -dict { PACKAGE_PIN W7  IOSTANDARD LVCMOS33 } [get_ports {led_d[3]}]
set_property -dict { PACKAGE_PIN U3  IOSTANDARD LVCMOS33 } [get_ports {led_d[2]}]
set_property -dict { PACKAGE_PIN U2  IOSTANDARD LVCMOS33 } [get_ports {led_d[1]}]
set_property -dict { PACKAGE_PIN W6  IOSTANDARD LVCMOS33 } [get_ports {led_d[0]}]
set_property -dict { PACKAGE_PIN V4  IOSTANDARD LVCMOS33 } [get_ports led_dh_latch]
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports led_dl_latch]
set_property -dict { PACKAGE_PIN U4  IOSTANDARD LVCMOS33 } [get_ports led_d_blank]
set_property -dict { PACKAGE_PIN U7  IOSTANDARD LVCMOS33 } [get_ports led_a3_latch]
set_property -dict { PACKAGE_PIN U8  IOSTANDARD LVCMOS33 } [get_ports led_a2_latch]
set_property -dict { PACKAGE_PIN V8  IOSTANDARD LVCMOS33 } [get_ports led_a32_blank]
set_property -dict { PACKAGE_PIN W4  IOSTANDARD LVCMOS33 } [get_ports led_a1_latch]
set_property -dict { PACKAGE_PIN V5  IOSTANDARD LVCMOS33 } [get_ports led_a0_latch]
set_property -dict { PACKAGE_PIN U5  IOSTANDARD LVCMOS33 } [get_ports led_a10_blank]
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports led_q]

set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 PULLUP true } [get_ports sw_input_nc_n]
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 PULLUP true } [get_ports sw_load_nc_n]
set_property -dict { PACKAGE_PIN V2  IOSTANDARD LVCMOS33 PULLUP true } [get_ports sw_mp_n]
set_property -dict { PACKAGE_PIN U1  IOSTANDARD LVCMOS33 PULLUP true } [get_ports sw_run]
set_property -dict { PACKAGE_PIN K3  IOSTANDARD LVCMOS33 PULLUP true } [get_ports {sw_d[7]}]
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {sw_d[6]}]
set_property -dict { PACKAGE_PIN M3  IOSTANDARD LVCMOS33 PULLUP true } [get_ports {sw_d[5]}]
set_property -dict { PACKAGE_PIN L2  IOSTANDARD LVCMOS33 PULLUP true } [get_ports {sw_d[4]}]
set_property -dict { PACKAGE_PIN N2  IOSTANDARD LVCMOS33 PULLUP true } [get_ports {sw_d[3]}]
set_property -dict { PACKAGE_PIN M1  IOSTANDARD LVCMOS33 PULLUP true } [get_ports {sw_d[2]}]
set_property -dict { PACKAGE_PIN W2  IOSTANDARD LVCMOS33 PULLUP true } [get_ports {sw_d[1]}]
set_property -dict { PACKAGE_PIN W3  IOSTANDARD LVCMOS33 PULLUP true } [get_ports {sw_d[0]}]

set_property -dict { PACKAGE_PIN R3  IOSTANDARD LVCMOS33 } [get_ports csync_n]
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports video]

set_property -dict { PACKAGE_PIN N1  IOSTANDARD LVCMOS33 } [get_ports uart_txd]
set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports uart_rxd]
set_property -dict { PACKAGE_PIN T3  IOSTANDARD LVCMOS33 } [get_ports uart_rtr_n]
set_property -dict { PACKAGE_PIN H2  IOSTANDARD LVCMOS33 PULLUP true } [get_ports uart_cts_n]

set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {config_sw_n[1]}]
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {config_sw_n[2]}]
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {config_sw_n[3]}]
set_property -dict { PACKAGE_PIN H1  IOSTANDARD LVCMOS33 PULLUP true } [get_ports {config_sw_n[4]}]
set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 PULLUP true } [get_ports {config_sw_n[5]}]
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 PULLUP true } [get_ports {config_sw_n[6]}]

set_property -dict { PACKAGE_PIN M2  IOSTANDARD LVCMOS33 PULLUP true } [get_ports sd_cd_n]
set_property -dict { PACKAGE_PIN T1  IOSTANDARD LVCMOS33             } [get_ports sd_cs_n]
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33             } [get_ports spi_clk]
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33             } [get_ports spi_mosi]
set_property -dict { PACKAGE_PIN T2  IOSTANDARD LVCMOS33 PULLUP true } [get_ports spi_miso]
