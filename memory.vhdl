-- Memory for COSMAC ELF test
-- Copyright 2009, 2013, 2017 Eric Smith <eric@brouhaha.com>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory is
  
  port (
    clk:         in  std_logic;
    address:     in  std_logic_vector (15 downto 0);
    mem_read:    in  std_logic;
    mem_write:   in  std_logic;
    data_in:     in  std_logic_vector (7 downto 0);
    data_out:    out std_logic_vector (7 downto 0)
  );

end memory;

architecture rtl of memory is

  constant addr_bits_used: integer := 16;
  constant max_addr: integer := 2 ** addr_bits_used - 1;

  subtype byte_t is std_logic_vector (7 downto 0);

  type byte_array_t is array (0 to max_addr) of byte_t;


  signal addr: unsigned (addr_bits_used - 1 downto 0);

  signal mem: byte_array_t := (
    others => std_logic_vector (to_unsigned (16#00#, 8))
  );

begin
  addr <= unsigned (address (addr_bits_used - 1 downto 0));

  mem_p: process (clk)
  begin  -- process r_p
    if falling_edge (clk) then
      if mem_write = '1' then
        mem (to_integer (addr)) <= data_in;
      end if;
      if mem_read = '1' then
        data_out <= mem (to_integer (addr));
      end if;
    end if;
  end process mem_p;

end rtl;
