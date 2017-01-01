-- Switch debouncer for COSMAC ELF
-- Copyright 2009, 2016 Eric Smith <eric@brouhaha.com>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity debouncer is
  --generic (clk_freq:      real;
  --         debounce_time: time);
  port (clk:    in  std_logic;
        raw_sw: in  std_logic;
        deb_sw: out std_logic);
end debouncer;

architecture rtl of debouncer is

  -- XXX The following don't work in Vivado 2016.4 due to bugs in
  --     VHDL time calculations
  --     forum post
  --       https://forums.xilinx.com/t5/Synthesis/Physical-type-TIME-is-broken-in-synthesis-of-Vivado-2015-4/td-p/684711
  --     answer record
  --       https://www.xilinx.com/support/answers/57964.html
  --constant clk_period:    time := 1 sec / clk_freq;
  --constant max_count:     integer := debounce_time / clk_period;
  constant max_count: integer := 125_000;  -- assuming 5 ms and 25 MHz
  constant counter_width: natural := integer (ceil (log2 (real (max_count))));

  signal state:   std_logic;
  signal counter: unsigned (counter_width - 1 downto 0);

begin

  deb_sw <= state;

  debounce_p: process (clk)
  begin
    if rising_edge (clk) then
      if raw_sw = state then
        counter <= to_unsigned (max_count - 1, counter_width);
      --elsif counter = max_count - 1 then
      elsif counter = 0 then
        state <= raw_sw;
        --counter <= to_unsigned (max_count - 1, counter_width);
      else
        counter <= counter - 1;
      end if;
    end if;
  end process debounce_p;

end rtl;
