-- COSMAC Elf
-- Copyright 2009, 2010 Eric Smith <eric@brouhaha.com>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elf is

  port (
    ext_clk:      in  std_logic;

-- switches
    input_pb:     in  std_logic;         -- pushbutton
    load_tog:     in  std_logic;
    mem_prot_tog: in  std_logic;
    run_tog:      in  std_logic;
    data_tog:     in  std_logic_vector (7 downto 0);

-- LEDs:
    data_led:     out std_logic_vector (7 downto 0);
	 led_msd_latch: out std_logic;
	 led_msd_blank: out std_logic;
	 led_lsd_latch: out std_logic;
	 led_lsd_blank: out std_logic;
    q_led:        out std_logic
  );

end elf;

architecture rtl of elf is

  -- clock signals
  signal clk25m:      std_logic;
  signal clk_divide:  unsigned (6 downto 0);
  signal system_clk:  std_logic;
  signal dcm_locked:  std_logic;

  -- reset signals
  signal other_reset: std_logic;        -- true if ext_reset or not dcm_locked
  signal reset:       std_logic;        -- system reset to synchronous logic

  -- debouncer clock, derived from system clock
  signal debounce_clk_counter : unsigned (15 downto 0);
  signal debounce_clk:  std_logic;

  -- debounced switch inputs
  signal input_pb_deb:  std_logic;
  signal load_tog_deb:  std_logic;
  signal mem_prot_tog_deb: std_logic;
  signal run_tog_deb:   std_logic;
  
  -- delayed switch input for edge detection
  signal input_pb_deb_del : std_logic;

  -- 1802 core signals
  signal dma_in_req:    std_logic;
  signal dma_out_req:   std_logic;
  signal int_req:       std_logic;
  signal wait_req:      std_logic;
  signal ef:            std_logic_vector (4 downto 1);
  signal proc_data_in:  std_logic_vector (7 downto 0) := (others => '0');
  signal proc_data_out: std_logic_vector (7 downto 0) := (others => '0');
  signal address:       std_logic_vector (15 downto 0) := (others => '0');
  signal mem_read:      std_logic;
  signal mem_write:     std_logic;
  signal io_port:       std_logic_vector (2 downto 0);
  signal q_out:         std_logic;
  signal sc:            std_logic_vector (1 downto 0);

  -- memory signals
  signal mem_write_gated: std_logic;
  signal mem_data_out:  std_logic_vector (7 downto 0);
  signal mem_data_in:   std_logic_vector (7 downto 0);

  -- state codes
  constant sc_fetch:     std_logic_vector (1 downto 0) := "00";
  constant sc_execute:   std_logic_vector (1 downto 0) := "01";
  constant sc_dma:       std_logic_vector (1 downto 0) := "10";
  constant sc_interrupt: std_logic_vector (1 downto 0) := "11";

begin

  my_dcm: entity work.dcm_wrapper (BEHAVIORAL)
             port map (clkin_in        => ext_clk,
                       clkfx_out       => clk25m,
                       clkin_ibufg_out => open,
                       locked_out      => dcm_locked);

  --clk_divide_p: process (clk25m)
  --begin
  --  if rising_edge (system_clk) then
  --    if clk_divide = ("0000000") then
  --		 clk_divide <= to_unsigned (50, 7);
  --		 system_clk <= not system_clk;
  --	  else
  --	    clk_divide <= clk_divide - 1;
  --	  end if;
  --  end if;
  --end process;
  
  system_clk <= clk25m;

  other_reset <= (not run_tog_deb) or (not dcm_locked);

  reset_gen: entity work.reset_gen (rtl)
             port map (clk => system_clk,
                       ext_reset => other_reset,
                       reset => reset);

  debounce_clk_p: process (clk25m)
  begin
    if rising_edge (clk25m) then
      debounce_clk_counter <= debounce_clk_counter + 1;
    end if;
  end process;

  debounce_clk <= debounce_clk_counter (debounce_clk_counter'left);

  input_pb_debouncer: entity work.debouncer (rtl)
    port map (
      clk    => debounce_clk,
      raw_sw => input_pb,
      deb_sw => input_pb_deb
    );

  load_tog_debouncer: entity work.debouncer (rtl)
    port map (
      clk    => debounce_clk,
      raw_sw => load_tog,
      deb_sw => load_tog_deb
    );

  mem_prot_tog_debouncer: entity work.debouncer (rtl)
    port map (
      clk    => debounce_clk,
      raw_sw => mem_prot_tog,
      deb_sw => mem_prot_tog_deb
    );

  run_tog_debouncer: entity work.debouncer (rtl)
    port map (
      clk    => debounce_clk,
      raw_sw => run_tog,
      deb_sw => run_tog_deb
    );

  processor: entity work.cosmac (rtl)
             port map (clk => system_clk,
                       clear => reset,
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

  mem_write_gated <= mem_write and not mem_prot_tog_deb;

  memory: entity work.elf_ram_256 (rtl)
          port map (clk => system_clk,
	            address => address,
 		    mem_read => mem_read,
		    mem_write => mem_write_gated,
		    data_in => mem_data_in,
		    data_out => mem_data_out);

  wait_req <= load_tog_deb;

  dma_in_req_p: process (system_clk)
  begin
    if rising_edge (system_clk) then
      input_pb_deb_del <= input_pb_deb;
      if dma_in_req = '0' then
        if run_tog_deb = '0' and load_tog_deb = '1' and input_pb_deb_del = '0' and input_pb_deb = '1' then
          dma_in_req <= '1';
        end if;
      else
        --if run_tog_deb = '1' or load_tog_deb = '0' or sc = sc_dma then
          dma_in_req <= '0';
        --end if;
      end if;
    end if;
  end process;

  dma_out_req <= '0';
  int_req <= '0';

  ef (1) <= '0';
  ef (2) <= '0';
  ef (3) <= '0';
  ef (4) <= input_pb_deb;

  proc_data_in <= mem_data_out;
  
  mem_data_in <= data_tog when (io_port = "010" and mem_write = '1')
                               or (reset = '1' and wait_req = '1')
    -- inp instruction or load mode
    else proc_data_out;

  data_led_p: process (system_clk)
  begin
    if rising_edge (system_clk) then
      if (reset = '1') and (wait_req = '1') and (mem_read = '1') then
        -- load mode, all memory reads
        data_led <= mem_data_out;
      elsif (io_port = "100") and (mem_read = '1') then
        -- out instruction
        data_led <= mem_data_out;
      end if;
    end if;
  end process;

  led_msd_latch <= '0';
  led_msd_blank <= '0';
  led_lsd_latch <= '0';
  led_lsd_blank <= '0';

  q_led <= q_out;

end rtl;
