-- COSMAC ELF system
-- Copyright 2009, 2016 Eric Smith <spacewar@gmail.com

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elf is
  generic (clk_freq:      real := 25.0e6;
           debounce_time: time := 1 ms;
           uart_rate:     real := 19200.0);
  port (clk:           in     std_logic;

        sw_input:      in     std_logic;
        sw_load:       in     std_logic;
        sw_mp:         in     std_logic;
        sw_run:        in     std_logic;

        sw_data:       in     std_logic_vector(7 downto 0);

        led_address:   out    std_logic_vector(15 downto 0);
        led_data:      out    std_logic_vector(7 downto 0);
        led_q:         out    std_logic;

        rxd:           in     std_logic;
        txd:           out    std_logic);

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

  signal proc_data_in:         std_logic_vector (7 downto 0);
  signal proc_data_out:        std_logic_vector (7 downto 0);
  signal address:              std_logic_vector (15 downto 0);
  signal mem_read:             std_logic;
  signal mem_write:            std_logic;
  signal mem_write_gated:      std_logic;
  signal io_port:              std_logic_vector (2 downto 0);
  signal q_out:                std_logic;
  signal sc:                   std_logic_vector (1 downto 0);

  signal led_data_out:         std_logic_vector (7 downto 0);

  signal mem_write_data:       std_logic_vector (7 downto 0);
  signal mem_read_data:        std_logic_vector (7 downto 0);

  signal uart_reset:           std_logic;
  signal uart_rx_buf_full:     std_logic;
  signal uart_read_rx:         std_logic;
  signal uart_read_data:       std_logic_vector (7 downto 0);
  signal uart_tx_buf_empty:    std_logic;
  signal uart_load_tx:         std_logic;

begin

  sw_input_debouncer: entity work.debouncer (rtl)
    --generic map (clk_freq =>      clk_freq,
    --             debounce_time => debounce_time)
    port map (clk    => clk,
              raw_sw => sw_input,
              deb_sw => deb_sw_input);

  sw_load_debouncer: entity work.debouncer (rtl)
    --generic map (clk_freq =>      clk_freq,
    --             debounce_time => debounce_time)
    port map (clk    => clk,
              raw_sw => sw_load,
              deb_sw => deb_sw_load);

  sw_mp_debouncer: entity work.debouncer (rtl)
    --generic map (clk_freq =>      clk_freq,
    --             debounce_time => debounce_time)
    port map (clk    => clk,
              raw_sw => sw_mp,
              deb_sw => deb_sw_mp);

  sw_run_debouncer: entity work.debouncer (rtl)
    --generic map (clk_freq =>      clk_freq,
    --             debounce_time => debounce_time)
    port map (clk    => clk,
              raw_sw => sw_run,
              deb_sw => deb_sw_run);


  led_address   <= address;
  led_data      <= led_data_out;
  led_q         <= q_out;

  dma_out_req   <= '0';
  clear_req     <= not sw_run;
  int_req       <= '0';
  wait_req      <= sw_load;
  
  data_led_p: process (clk)
  begin
    if rising_edge (clk) then
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
  dma_in_req_p: process (clk)
  begin
    if rising_edge (clk) then
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
    
  ef (1)        <= uart_rx_buf_full;
  ef (2)        <= uart_tx_buf_empty;
  ef (3)        <= '0';
  ef (4)        <= deb_sw_input;

  processor: entity work.cosmac (rtl)
             port map (clk => clk,

                       clear => clear_req,
                       dma_in_req => dma_in_req,
                       dma_out_req => dma_out_req,
                       int_req => int_req,
                       wait_req => wait_req,

                       ef => ef,

                       data_in => proc_data_in,
                       data_out => proc_data_out,
                       address => address,
                       mem_read => mem_read,
                       mem_write => mem_write,
                       io_port => io_port,
                       q_out => q_out,
                       sc => sc);

  pixie_selected <= '1' when io_port = pixie_port
              else '0';

  switch_led_selected <= '1' when io_port = switch_led_port
              else '0';

  uart_selected <= '1' when io_port = uart_port
              else '0';

  proc_data_in <= mem_read_data;

  mem_write_gated <= mem_write and not deb_sw_mp;
  
  mem_write_data <= sw_data        when wait_req = '1'
               else sw_data        when switch_led_selected = '1'
  --           else uart_read_data when uart_selected = '1'
               else proc_data_out;

  memory: entity work.memory (rtl)
          port map (clk => clk,
	            address => address,
 		    mem_read => mem_read,
		    mem_write => mem_write_gated,
		    data_in => mem_write_data,
		    data_out => mem_read_data);

  -- XXX real UART not ready yet
  --uart: entity work.uart (rtl)
  --  port map (clk => clk,
  --            reset => uart_reset,
  --            brg_divisor => to_unsigned(163, 8),
  --            rx_buf_full => uart_rx_buf_full,
  --            read_rx => uart_read_rx,
  --            rx_data => uart_read_data,
  --            tx_buf_empty => uart_tx_buf_empty,
  --            load_tx => uart_load_tx,
  --            tx_data => proc_data_out,
  --            rxd => rxd,
  --            txd => txd);

  uart_reset <= not deb_sw_run;

  uart_read_rx <= '1' when mem_write = '1' and uart_selected = '1'
             else '0';

  uart_load_tx <= '1' when mem_read = '1' and uart_selected = '1'
             else '0';

  -- Fake UART
  uart_rx_buf_full  <= '0';
  uart_tx_buf_empty <= '0';
  txd <= '1';
  uart_read_data <= "00000000";

end rtl;