-- Xilinx 7-Series FPGA COSMAC ELF
-- Copyright 2009, 2016, 2017 Eric Smith <spacewar@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity elf_x7 is
  generic (clk_in_freq: real := 100.0e6;
           clk_freq:    real := 62.5e6;
           uart_rate:   real := 19200.0);
  port (i_100MHz_P:    in  std_logic;
        i_100MHz_N:    in  std_logic;
        RESET_N:       in  std_logic;

        sw_d:          in  std_logic_vector (7 downto 0);
        sw_load_nc_n:  in  std_logic;
        sw_input_nc_n: in  std_logic;
        sw_mp_n:       in  std_logic;
        sw_run:        in  std_logic;
        
        led_q:         out std_logic;
        led_spare:     out std_logic;
        led_d_le_n:    out std_logic;
        led_d_bl:      out std_logic;
        led_al_le_n:   out std_logic;
        led_al_bl:     out std_logic;
        led_ah_le_n:   out std_logic;
        led_ah_bl:     out std_logic;
        led_d:         out std_logic_vector (7 downto 0);
        led_a:         out std_logic_vector (15 downto 0);

        UART1_RXD:     in  std_logic;
        UART1_TXD:     out std_logic;
        UART1_RTS_N:   out std_logic;
        UART1_CTS_N:   in  std_logic);
end elf_x7;

architecture rtl of elf_x7 is

  signal clk_in:      std_logic;  -- from differential clock input buffer
  signal clk:         std_logic;  -- to elf

  signal reset_cntr:  unsigned (3 downto 0);
  signal reset:       std_logic;  -- to clock synth
  signal sync_reset:  std_logic;  -- to elf

  signal sw_input:    std_logic;
  signal sw_load:     std_logic;
  signal sw_mp:       std_logic;

  -- elf_load and elf_run are sw_load and sw_run gated to 0 when reset is active
  signal elf_load:    std_logic;
  signal elf_run:     std_logic;

  signal elf_addr:    std_logic_vector (15 downto 0);
  signal elf_data:    std_logic_vector (7 downto 0);
  signal elf_q:       std_logic;

begin

  sw_mp    <= not sw_mp_n;
  sw_input <= sw_input_nc_n;
  sw_load  <= sw_load_nc_n;

  -- LED outputs, all latch enables active, all blanking inactive
  led_spare     <= '0';

  led_q         <= elf_q;

  led_d_le_n    <= '0';
  led_d_bl      <= '0';
  led_d         <= elf_data;

  led_al_le_n   <= '0';
  led_al_bl     <= '0';
  led_ah_le_n   <= '0';
  led_ah_bl     <= '0';
  led_a         <= elf_addr;

  clock_in_buf: IBUFDS
    generic map (DIFF_TERM    => false,
                 ibuf_low_pwr => true,
                 iostandard   => "DEFAULT")
    port map (I  => i_100MHz_P,
              IB => i_100MHz_N,
              O  => clk_in);

  reset <= not RESET_N;

  clock_synth: entity work.clock_x7
    generic map (clk_in_freq => clk_in_freq)
    port map (reset   => reset,
              clk_in  => clk_in,
              clk_out => clk,
              locked  => open);

  reset_p: process (clk)
  begin
    if rising_edge (clk) then
      if RESET_N = '0' then
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
  
  elf_run  <= '1' when reset = '0' and sw_run = '1'
         else '0';
  elf_load <= '1' when reset = '0' and sw_load = '1'
         else '0';

  elf: entity work.elf (rtl)
    generic map (clk_freq => clk_freq,
                 uart_rate => uart_rate)
    port map (clk => clk,

              sw_input    => sw_input,
              sw_load     => elf_load,
              sw_mp       => sw_mp,
              sw_run      => elf_run,

              sw_data     => sw_d,

              led_address => elf_addr,
              led_data    => elf_data,
              led_q       => elf_q,

              rxd         => UART1_RXD,
              txd         => UART1_TXD);
              
  UART1_RTS_N <= '0';

end rtl;
