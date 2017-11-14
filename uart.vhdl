-- Simple UART
-- Copyright 2009, 2016, 2017 Eric Smith <spacewar@gmail.com>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
  generic (brg_divisor_width: natural := 16);
  port (
    clk:          in  std_logic;
    clk_enable:   in  std_logic := '1';
    reset:        in  std_logic;
    brg_divisor:  in  unsigned(brg_divisor_width - 1 downto 0);

    -- processor interface
    rx_buf_full:  out std_logic;
    read_rx:      in  std_logic;
    rx_data:      out std_logic_vector (7 downto 0);

    tx_buf_empty: out std_logic;
    load_tx:      in  std_logic;
    tx_data:      in  std_logic_vector (7 downto 0);

    -- serial interface
    rxd:          in  std_logic;
    txd:          out std_logic
  );
end uart;

architecture rtl of uart is

  signal brg_counter:    unsigned (brg_divisor_width - 1 downto 0);
  signal tx_16x_counter: unsigned (3 downto 0);
  signal rx_16x_counter: unsigned (3 downto 0);

  signal uart_clk_16x:   std_logic;
  signal uart_clk_1x:    std_logic;

  signal tbe: std_logic;
  signal tx_buf: std_logic_vector (7 downto 0);
  signal tx_reg: std_logic_vector (7 downto 0);

  signal rbf: std_logic;
  signal rx_buf: std_logic_vector (7 downto 0);
  signal rx_reg: std_logic_vector (7 downto 0);

  signal tx_state: unsigned (3 downto 0);
  constant tx_state_start: unsigned (3 downto 0) := "1010";
  -- data bits are 2 through 9
  constant tx_state_stop:  unsigned (3 downto 0) := "0001";
  constant tx_state_idle:  unsigned (3 downto 0) := "0000";

  signal rx_state: unsigned (3 downto 0);
  constant rx_state_start: unsigned (3 downto 0) := "1010";
  -- data bits are 2 through 9
  constant rx_state_stop:  unsigned (3 downto 0) := "0001";
  constant rx_state_idle:  unsigned (3 downto 0) := "0000";

begin

  tx_buf_empty <= tbe;
  rx_buf_full  <= rbf;
  
  rx_data <= rx_buf;

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
      if reset = '1' then
        tx_16x_counter <= "0000";
        tx_state <= tx_state_idle;
        txd <= '1';
        tbe <= '1';
      else
        if load_tx = '1' then
          tx_buf <= tx_data;
          tbe <= '0';
        end if;
        if uart_clk_16x = '1' then
          tx_16x_counter <= tx_16x_counter + 1;
          if tx_16x_counter = "0000" then
            if tx_state = tx_state_idle then
              txd <= '1';
              if tbe = '0' then
                tx_reg <= tx_buf;
                tbe <= '1';
                tx_state <= tx_state_start;
              end if;
            elsif tx_state = tx_state_start then
              txd <= '0';                   -- start bit
              tx_state <= tx_state - 1;
            elsif tx_state = tx_state_stop then
              txd <= '1';                   -- stop bit
              tx_state <= tx_state - 1;
            else
              txd <= tx_reg (0);
              tx_reg <= '0' & tx_reg (7 downto 1);
              tx_state <= tx_state - 1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process tx_p;

  rx_p: process (clk, clk_enable)
  begin
    if rising_edge (clk) and clk_enable = '1' then
      if reset = '1' then
        rx_16x_counter <= "0000";
        rx_state <= rx_state_idle;
        rbf <= '0';
      else
        if read_rx = '1' then
          rbf <= '0';
        end if;
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
                  if rbf = '1' then
                    null;                 -- receiver overrun error (ignore)
                  end if;
                  rx_buf <= rx_reg;
                  rbf <= '1';
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

end rtl;
