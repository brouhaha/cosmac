-- COSMAC processor core
-- Copyright 2009, 2010 Eric Smith <eric@brouhaha.com>
-- Instruction set compatible with CDP1802
-- Not bus compatible with CDP1802
-- Single clock cycle per machine cycle
-- Single cycle synchronous bus interface with separate data in and out

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cosmac is
  
  port (
    clk:         in  std_logic;
    clear:       in  std_logic;
    dma_in_req:  in  std_logic;
    dma_out_req: in  std_logic;
    int_req:     in  std_logic;
    wait_req:    in  std_logic;
    ef:          in  std_logic_vector (4 downto 1);
    data_in:     in  std_logic_vector (7 downto 0);
    data_out:    out std_logic_vector (7 downto 0);
    address:     out std_logic_vector (15 downto 0);
    mem_read:    inout std_logic;
    mem_write:   out std_logic;
    io_port:     inout std_logic_vector (2 downto 0);  -- n0-2 in RCA docs
    q_out:       out std_logic;
    sc:          out std_logic_vector (1 downto 0)
  );

end cosmac;

architecture rtl of cosmac is

  subtype nibble_t is std_logic_vector (3 downto 0);
  subtype byte_t is std_logic_vector (7 downto 0);
  subtype word_t is std_logic_vector (15 downto 0);

  type byte_register_file_t is array (0 to 15) of byte_t;

  -- instructions
  constant inst_idl: byte_t := x"00";
  constant inst_ldn:  byte_t := x"0" & "XXXX";
  constant inst_inc:  byte_t := x"1" & "XXXX";
  constant inst_dec:  byte_t := x"2" & "XXXX";

  constant inst_short_branch:  byte_t := x"3" & "XXXX";
  constant inst_lda:  byte_t := x"4" & "XXXX";
  constant inst_str:  byte_t := x"5" & "XXXX";
  constant inst_irx:  byte_t := x"60";
  constant inst_out:  byte_t := x"6" & "0XXX";
  constant inst_extend: byte_t := x"68";
  constant inst_inp:  byte_t := x"6" & "1XXX";
  constant inst_ret:  byte_t := x"70";
  constant inst_dis:  byte_t := x"71";
  constant inst_ldxa: byte_t := x"72";
  constant inst_stxd: byte_t := x"73";
  constant inst_adc:  byte_t := x"74";
  constant inst_sdb:  byte_t := x"75";
  constant inst_shrc: byte_t := x"76";
  constant inst_smb:  byte_t := x"77";
  constant inst_sav:  byte_t := x"78";
  constant inst_mark: byte_t := x"79";
  constant inst_req:  byte_t := x"7a";
  constant inst_seq:  byte_t := x"7b";
  constant inst_adci: byte_t := x"7c";
  constant inst_sdbi: byte_t := x"7d";
  constant inst_shlc: byte_t := x"7e";
  constant inst_smbi: byte_t := x"7f";
  constant inst_glo:  byte_t := x"8" & "XXXX";
  constant inst_ghi:  byte_t := x"9" & "XXXX";
  constant inst_plo:  byte_t := x"a" & "XXXX";
  constant inst_phi:  byte_t := x"b" & "XXXX";
  constant inst_long_branch_skip:  byte_t := x"c" & "XXXX";
  constant inst_sep:  byte_t := x"d" & "XXXX";
  constant inst_sex:  byte_t := x"e" & "XXXX";
  constant inst_ldx:  byte_t := x"f0";
  constant inst_or:   byte_t := x"f1";
  constant inst_and:  byte_t := x"f2";
  constant inst_xor:  byte_t := x"f3";
  constant inst_add:  byte_t := x"f4";
  constant inst_sub:  byte_t := x"f5";
  constant inst_shr:  byte_t := x"f6";
  constant inst_sm:   byte_t := x"f7";
  constant inst_ldi:  byte_t := x"f8";
  constant inst_ori:  byte_t := x"f9";
  constant inst_ani:  byte_t := x"fa";
  constant inst_xri:  byte_t := x"fb";
  constant inst_adi:  byte_t := x"fc";
  constant inst_sdi:  byte_t := x"fd";
  constant inst_shl:  byte_t := x"fe";
  constant inst_smi:  byte_t := x"ff";

  constant sc_fetch:     std_logic_vector (1 downto 0) := "00";
  constant sc_execute:   std_logic_vector (1 downto 0) := "01";
  constant sc_dma:       std_logic_vector (1 downto 0) := "10";
  constant sc_interrupt: std_logic_vector (1 downto 0) := "11";

  -- CPU registers
  signal state: std_logic_vector (3 downto 0);
  signal next_state: std_logic_vector (3 downto 0);
  constant state_clear:       std_logic_vector (3 downto 0) := "0000";  -- sc_execute
  constant state_clear_2:     std_logic_vector (3 downto 0) := "0001";  -- sc_execute
  constant state_load:        std_logic_vector (3 downto 0) := "0010";  -- sc_execute
  constant state_fetch:       std_logic_vector (3 downto 0) := "0011";  -- sc_fetch
  constant state_execute:     std_logic_vector (3 downto 0) := "0100";  -- sc_execute
  constant state_execute_2:   std_logic_vector (3 downto 0) := "0101";  -- sc_execute
  constant state_dma_in:      std_logic_vector (3 downto 0) := "0110";  -- sc_dma
  constant state_dma_out:     std_logic_vector (3 downto 0) := "0111";  -- sc_dma
  constant state_interrupt:   std_logic_vector (3 downto 0) := "1000";  -- sc_interrupt

  signal r_low:   byte_register_file_t := (others => "00000000");
  signal r_high:  byte_register_file_t := (others => "00000000");

  signal ir: byte_t;   -- instruction register
  alias i:  nibble_t is ir (7 downto 4);  -- high nibble of ir
  alias n:  nibble_t is ir (3 downto 0);  -- low nibble of ir

  signal d:  byte_t;
  signal df: std_logic;

  signal x:  nibble_t;
  signal p:  nibble_t;

  signal t:  byte_t;                    -- holds old X, P after interrupt

  signal ie:  std_logic;                -- interrupt enable
  signal q:  std_logic;                 -- output flip-flop

  -- other data path signals
  signal d_zero: std_logic;

  signal prev_data_in: byte_t;          -- prev cycle value of data_in, used
  	 	       			-- for long branch
  signal cond_branch:      std_logic;
  signal cond_no_skip:     std_logic;

  signal r_addr:           nibble_t;
  signal r_write_data:     word_t;
  signal r_read_data:      word_t;
  signal r_read_data_byte: byte_t;

  signal adder_opb:        word_t;
  signal adder_result:     word_t;

  signal alu_carry_in:   unsigned (0 downto 0);
  signal alu_op_d:       unsigned (8 downto 0);
  signal alu_op_data_in: unsigned (8 downto 0);
  signal alu_sum:        unsigned (8 downto 0);
  signal alu_out:        byte_t;

  signal rotate_in:      std_logic;     -- bit rotated in, 0 for shifts

  signal shifter_out:    byte_t;

  -- control signals
  signal waiting: std_logic;
  
  signal r_addr_sel: std_logic_vector (2 downto 0);
  constant r_addr_sel_p : std_logic_vector (2 downto 0) := "000";
  constant r_addr_sel_n : std_logic_vector (2 downto 0) := "001";
  constant r_addr_sel_2 : std_logic_vector (2 downto 0) := "010";
  constant r_addr_sel_x : std_logic_vector (2 downto 0) := "011";
  constant r_addr_sel_0 : std_logic_vector (2 downto 0) := "100";

  signal r_write_data_sel: std_logic_vector (2 downto 0);
  constant r_write_data_sel_adder:   std_logic_vector (2 downto 0) := "000";
  constant r_write_data_sel_branch:  std_logic_vector (2 downto 0) := "001";
  constant r_write_data_sel_d:       std_logic_vector (2 downto 0) := "010";
  constant r_write_data_sel_data_in: std_logic_vector (2 downto 0) := "011";
  constant r_write_data_sel_0:       std_logic_vector (2 downto 0) := "100";

  signal r_write_low:   std_logic;
  signal r_write_high:  std_logic;

  signal data_out_sel: std_logic_vector (1 downto 0);
  constant data_out_sel_d:  std_logic_vector (1 downto 0) := "00";
  constant data_out_sel_xp: std_logic_vector (1 downto 0) := "01";  -- mark
  constant data_out_sel_t:  std_logic_vector (1 downto 0) := "10";  -- sav

  signal d_sel: std_logic_vector (2 downto 0);
  constant d_sel_hold:     std_logic_vector (2 downto 0) := "000";
  constant d_sel_data_in:  std_logic_vector (2 downto 0) := "001";
  constant d_sel_alu:      std_logic_vector (2 downto 0) := "010";
  constant d_sel_shifter:  std_logic_vector (2 downto 0) := "011";
  constant d_sel_r:        std_logic_vector (2 downto 0) := "100";
  constant d_sel_0:        std_logic_vector (2 downto 0) := "101";

  signal df_sel: std_logic_vector (1 downto 0);
  constant df_sel_hold:  std_logic_vector (1 downto 0) := "00";
  constant df_sel_carry: std_logic_vector (1 downto 0) := "01";
  constant df_sel_d0:    std_logic_vector (1 downto 0) := "10";
  constant df_sel_d7:    std_logic_vector (1 downto 0) := "11";

  signal xp_sel: std_logic_vector (2 downto 0);
  constant xp_sel_hold:      std_logic_vector (2 downto 0) := "000";
  constant xp_sel_clear:     std_logic_vector (2 downto 0) := "001";  -- clear
  constant xp_sel_interrupt: std_logic_vector (2 downto 0) := "010";  -- p<=1, x<=2
  constant xp_sel_data_in:   std_logic_vector (2 downto 0) := "011";  -- ret, dis
  constant xp_sel_mark:      std_logic_vector (2 downto 0) := "100";  -- x<=p
  constant xp_sel_sep:       std_logic_vector (2 downto 0) := "101";  -- p<=n
  constant xp_sel_sex:       std_logic_vector (2 downto 0) := "110";  -- x<=n

  signal ie_sel: std_logic_vector (1 downto 0);
  constant ie_sel_hold:      std_logic_vector (1 downto 0) := "00";
  constant ie_sel_not_ir0:   std_logic_vector (1 downto 0) := "01";
  constant ie_sel_0:         std_logic_vector (1 downto 0) := "10";
  constant ie_sel_1:         std_logic_vector (1 downto 0) := "11";

  signal q_sel: std_logic_vector (1 downto 0);
  constant q_sel_hold:       std_logic_vector (1 downto 0) := "00";
  constant q_sel_ir0:        std_logic_vector (1 downto 0) := "01";
  constant q_sel_0:          std_logic_vector (1 downto 0) := "10";
  constant q_sel_1:          std_logic_vector (1 downto 0) := "11";

  signal load_ir:            std_logic;      -- true to load IR from data in
  signal load_t:             std_logic;      -- true to load T from X & P

  signal adder_opb_sel: std_logic_vector (1 downto 0);
  constant adder_opb_sel_0:    std_logic_vector (1 downto 0) := "00";
  constant adder_opb_sel_1:    std_logic_vector (1 downto 0) := "01";
  constant adder_opb_sel_m1:   std_logic_vector (1 downto 0) := "11";
  constant adder_opb_sel_m128: std_logic_vector (1 downto 0) := "10";  -- not used

begin
  q_out <= q;

  r_read_data <= r_high (to_integer (unsigned (r_addr))) & r_low (to_integer (unsigned (r_addr)));

  address <= r_read_data;

  adder_opb <= x"0001" when adder_opb_sel = adder_opb_sel_1
          else x"ffff" when adder_opb_sel = adder_opb_sel_m1
          else x"8000" when adder_opb_sel = adder_opb_sel_m128
          else x"0000";

  adder_result <= std_logic_vector (unsigned (r_read_data) + unsigned (adder_opb));

  r_read_data_byte <= r_read_data (15 downto 8) when ir (4) = '1'
                 else r_read_data (7 downto 0);

  alu_op_d       <= unsigned ('0' & not d) when ir (1 downto 0) = "01"
               else unsigned ('0' & d);

  alu_op_data_in <= unsigned ('0' & not data_in) when ir (1 downto 0) = "11"
               else unsigned ('0' & data_in);

  alu_carry_in (0) <= df when ir (7) = '0'
                else ir (0);

  alu_sum <= alu_op_d + alu_op_data_in + alu_carry_in;

  alu_out <= d or  data_in when ir (2 downto 0) = "001"
        else d and data_in when ir (2 downto 0) = "010"
        else d xor data_in when ir (2 downto 0) = "011"
        else std_logic_vector (alu_sum (7 downto 0)); -- alu_op_add             

  rotate_in <= df when ir (7) = '0'
          else '0';

  shifter_out <= d (6 downto 0) & rotate_in when ir (3) = '1'
            else rotate_in & d (7 downto 1);

  r_addr <= p when r_addr_sel = r_addr_sel_p  -- inst fetch, branch, skip, immed
            else n when r_addr_sel = r_addr_sel_n
            else x when r_addr_sel = r_addr_sel_x
            else x"2" when r_addr_sel = r_addr_sel_2  -- mark
            else x"0";                -- clear, dma in, dma out

  r_write_data <= data_in & data_in when r_write_data_sel = r_write_data_sel_data_in
             else d & d when r_write_data_sel = r_write_data_sel_d
             else x"0000" when r_write_data_sel = r_write_data_sel_0
             else prev_data_in & data_in when r_write_data_sel = r_write_data_sel_branch and cond_branch = '1'
             else adder_result;

  data_out <= x & p when data_out_sel = data_out_sel_xp  -- mark
              else t when data_out_sel = data_out_sel_t  -- sav
              else d;

  io_port <= n (2 downto 0) when state = state_execute and i = inst_out (7 downto 4) else "000";

  waiting <= '1' when (wait_req = '1') and (clear = '0')
        else '0';

  r_p: process (clk)
  begin  -- process r_p
    if rising_edge (clk) then
      if waiting = '0' then
        if r_write_low = '1' then
          r_low (to_integer (unsigned (r_addr))) <= r_write_data (7 downto 0);
        end if;
        if r_write_high = '1' then
          r_high (to_integer (unsigned (r_addr))) <= r_write_data (15 downto 8);
        end if;
      end if;
    end if;
  end process r_p;

  xp_p: process (clk)
  begin
    if rising_edge (clk) then
      if waiting = '0' then
        if xp_sel = xp_sel_clear then
          p <= x"0";
          x <= x"0";
        elsif xp_sel = xp_sel_interrupt then
          p <= x"1";
          x <= x"2";
        elsif xp_sel = xp_sel_data_in then
          p <= data_in (3 downto 0);
          x <= data_in (7 downto 4);
        elsif xp_sel = xp_sel_mark then
          x <= p;
        elsif xp_sel = xp_sel_sep then
          p <= n;
        elsif xp_sel = xp_sel_sex then
          x <= n;
        else
          null;                           -- xp_sel_hold: x and p unchanged
        end if;
      end if;
    end if;
  end process xp_p;

  d_p: process (clk)
  begin
    if rising_edge (clk) then
      if waiting = '0' then
        if d_sel = d_sel_data_in then
          d <= data_in;
        elsif d_sel = d_sel_alu then
          d <= alu_out;
        elsif d_sel = d_sel_shifter then
          d <= shifter_out;
        elsif d_sel = d_sel_r then
          d <= r_read_data_byte;
        elsif d_sel = d_sel_0 then
          d <= "00000000";
        else
          null;                           -- d_sel_hold: d unchanged
        end if;
      end if;
    end if;
  end process d_p;

  df_p: process (clk)
  begin
    if rising_edge (clk) then
      if waiting = '0' then
        if df_sel = df_sel_carry then
          df <= alu_sum (8);
        elsif df_sel = df_sel_d0 then
          df <= d (0);
        elsif df_sel = df_sel_d7 then
          df <= d (7);
        else
          null;                           -- df_sel_hold: df unchanged
        end if;
      end if;
    end if;
  end process df_p;

  ir_p: process (clk)
  begin
    if rising_edge (clk) then
      if waiting = '0' then
        if load_ir = '1' then
          ir <= data_in;
        end if;
      end if;
    end if;
  end process ir_p;

  t_p: process (clk)
  begin
    if rising_edge (clk) then
      if waiting = '0' then
        if load_t = '1' then
          t <= x & p;
        end if;
      end if;
    end if;
  end process t_p;

  q_p: process (clk)
  begin
    if rising_edge (clk) then
      if waiting = '0' then
        if q_sel = q_sel_0 then
          q <= '0';
        elsif q_sel = q_sel_1 then
          q <= '1';
        elsif q_sel = q_sel_ir0 then
          q <= ir (0);
        else
          null;                           -- q_sel_hold: q unchanged
        end if;
      end if;
    end if;
  end process q_p;

  ie_p: process (clk)
  begin
    if rising_edge (clk) then
      if waiting = '0' then
        if ie_sel = ie_sel_0 then
          ie <= '0';
        elsif ie_sel = ie_sel_1 then
          ie <= '1';
        elsif ie_sel = ie_sel_not_ir0 then
          ie <= not ir (0);
        else
          null;                           -- ie_sel_hold: ie unchanged
        end if;
      end if;
    end if;
  end process ie_p;

  prev_data_in_p: process (clk)
  begin
    if rising_edge (clk) then
      if waiting = '0' then
        prev_data_in <= data_in;
      end if;
    end if;
  end process prev_data_in_p;

  d_zero <= '1' when d = x"00" else '0';

  cond_branch_p: process (ir, q, d_zero, df, ef)
    variable cond_branch_no_pol: std_logic;
  begin
    case ir (2 downto 0) is
      when "000" => cond_branch_no_pol := '1';
      when "001" => cond_branch_no_pol := q;
      when "010" => cond_branch_no_pol := d_zero;
      when "011" => cond_branch_no_pol := df;
      when "100" => cond_branch_no_pol := ef (1);
      when "101" => cond_branch_no_pol := ef (2);
      when "110" => cond_branch_no_pol := ef (3);
      when "111" => cond_branch_no_pol := ef (4);
      when others => null;
    end case;
    cond_branch <= cond_branch_no_pol xor ir (3);
  end process cond_branch_p;
    
  cond_no_skip_p: process (ir, ie, q, d_zero, df)
    variable cond_no_skip_no_pol: std_logic;
  begin
    case ir (1 downto 0) is
      when "00" =>
        if ir (3) = '1' then
          cond_no_skip_no_pol := ie;
        else
          cond_no_skip_no_pol := '1';
        end if;
      when "01" => cond_no_skip_no_pol := q;
      when "10" => cond_no_skip_no_pol := d_zero;
      when "11" => cond_no_skip_no_pol := df;
      when others => null;
    end case;
    cond_no_skip <= cond_no_skip_no_pol xor ir (3);
  end process cond_no_skip_p;

  control_p: process (state, ir, dma_in_req, dma_out_req,
                      int_req, ie, cond_no_skip)
  begin  -- process control_p
    -- default control outputs:
    r_addr_sel <= r_addr_sel_p;
    r_write_data_sel <= r_write_data_sel_adder;
    r_write_high <= '0';
    r_write_low <= '0';
    mem_read <= '0';
    mem_write <= '0';
    data_out_sel <= data_out_sel_d;
    d_sel <= d_sel_hold;
    df_sel <= df_sel_hold;
    load_ir <= '0';
    load_t <= '0';
    q_sel <= q_sel_hold;
    ie_sel <= ie_sel_hold;
    xp_sel <= xp_sel_hold;
    adder_opb_sel <= adder_opb_sel_1;
    sc <= state_execute;
    next_state <= state;
    
    -- control outputs based on state, ir:
    case state is
      when state_clear =>
        sc <= sc_execute;
        next_state <= state_clear_2;
        d_sel <= d_sel_0;
        xp_sel <= xp_sel_clear;
        q_sel <= q_sel_0;
        ie_sel <= ie_sel_1;
        r_addr_sel <= r_addr_sel_0;
        r_write_data_sel <= r_write_data_sel_0;
        r_write_high <= '1';
        r_write_low <= '1';
      when state_clear_2 =>
        sc <= sc_execute;
        df_sel <= df_sel_d0;
        if clear = '0' then
          next_state <= state_fetch;
        elsif wait_req = '1' then
          -- subtract one from PC
          r_addr_sel <= r_addr_sel_p;
          adder_opb_sel <= adder_opb_sel_m1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          mem_read <= '1';
          next_state <= state_load;
        end if;
      when state_load =>
        sc <= sc_execute;
        r_addr_sel <= r_addr_sel_p;
        mem_read <= '1';
        if dma_in_req = '1' then
          -- add one to PC
          r_addr_sel <= r_addr_sel_p;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          next_state <= state_dma_in;
        elsif dma_out_req = '1' then
          -- add one to PC
          r_addr_sel <= r_addr_sel_p;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          next_state <= state_dma_out;
        elsif clear = '0' then
          -- We don't need to explicity handle the transition from
          -- load to reset, but we do need to handle a transition
          -- from load to run, forcing a reset.
          next_state <= state_clear;
        end if;
      when state_fetch => 
        sc <= sc_fetch;
--        if data_in = inst_extend then
--          next_state <= state_fetch_2;
--        else
          next_state <= state_execute;
--        end if;
        r_addr_sel <= r_addr_sel_p;
        adder_opb_sel <= adder_opb_sel_1;
        r_write_data_sel <= r_write_data_sel_adder;
        r_write_high <= '1';
        r_write_low <= '1';
        mem_read <= '1';
        load_ir <= '1';
      when state_execute =>
        sc <= sc_execute;
        if dma_in_req = '1' then
          next_state <= state_dma_in;
        elsif dma_out_req = '1' then
          next_state <= state_dma_out;
        elsif int_req = '1' and ie = '1' then
          next_state <= state_interrupt;
        elsif ir = inst_idl then
          next_state <= state_execute;
        else
          next_state <= state_fetch;
        end if;
        if ir = inst_idl then
          r_addr_sel <= r_addr_sel_0;
          mem_read <= '1';
        elsif i = inst_ldn (7 downto 4) then
          r_addr_sel <= r_addr_sel_n;
          mem_read <= '1';
          d_sel <= d_sel_data_in;
        elsif i = inst_inc (7 downto 4) then
          r_addr_sel <= r_addr_sel_n;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
        elsif i = inst_dec (7 downto 4) then
          r_addr_sel <= r_addr_sel_n;
          adder_opb_sel <= adder_opb_sel_m1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
        elsif i = inst_short_branch (7 downto 4) then
          r_addr_sel <= r_addr_sel_p;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_branch;
          r_write_high <= '0';
          r_write_low <= '1';
          mem_read <= '1';
        elsif i = inst_lda (7 downto 4) then
          r_addr_sel <= r_addr_sel_n;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          mem_read <= '1';
          d_sel <= d_sel_data_in;
        elsif i = inst_str (7 downto 4) then
          r_addr_sel <= r_addr_sel_n;
          data_out_sel <= data_out_sel_d;
          mem_write <= '1';
--        elsif ir = inst_irx then
--          r_addr_sel <= r_addr_sel_x;
--          adder_opb_sel <= adder_opb_sel_1;
--          r_write_data_sel <= r_write_data_sel_adder;
--          r_write_high <= '1';
--          r_write_low <= '1';
        elsif i = inst_out (7 downto 4) and n (3) = '0' then
          -- out
          -- Note: we also handle irx here.  It has a superfluous memory
          -- read, but the real 1802 probably also had that.
          r_addr_sel <= r_addr_sel_x;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          mem_read <= '1';
--        elsif ir = inst_extend then
--          r_addr_sel <= r_addr_sel_p;
--          adder_opb_sel <= adder_opb_sel_1;
--          r_write_data_sel <= r_write_data_sel_adder;
--          r_write_high <= '1';
--          r_write_low <= '1';
--          mem_read <= '1';
--          load_ir <= '1';
        elsif i = inst_inp (7 downto 4) and n (3) = '1' then
          -- inp
          -- Note: also handle undefined opcode 68 here, which is used
          -- as an extended opcode prefix in the 1804/05/06.
          r_addr_sel <= r_addr_sel_x;
          mem_write <= '1';
          d_sel <= d_sel_data_in;
        elsif ir = inst_ret or ir = inst_dis then
          r_addr_sel <= r_addr_sel_x;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          mem_read <= '1';
          xp_sel <= xp_sel_data_in;
          ie_sel <= ie_sel_not_ir0;
        elsif ir = inst_ldxa then
          r_addr_sel <= r_addr_sel_x;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          mem_read <= '1';
          d_sel <= d_sel_data_in;
        elsif ir = inst_stxd then
          r_addr_sel <= r_addr_sel_x;
          adder_opb_sel <= adder_opb_sel_1;
          data_out_sel <= data_out_sel_d;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          mem_write <= '1';
        elsif ir = inst_adc or ir = inst_sdb or ir = inst_smb or
              ir = inst_add or ir = inst_sub or ir = inst_sm then
          r_addr_sel <= r_addr_sel_x;
          mem_read <= '1';
          d_sel <= d_sel_alu;
          df_sel <= df_sel_carry;
        elsif ir = inst_shrc or ir = inst_shr then
          d_sel <= d_sel_shifter;
          df_sel <= df_sel_d0;
        elsif ir = inst_sav then
          r_addr_sel <= r_addr_sel_x;
          data_out_sel <= data_out_sel_t;
          mem_write <= '1';
        elsif ir = inst_mark then
          r_addr_sel <= r_addr_sel_2;
          adder_opb_sel <= adder_opb_sel_m1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          data_out_sel <= data_out_sel_xp;
          load_t <= '1';
          xp_sel <= xp_sel_mark;
        elsif ir = inst_req or ir = inst_seq then
          q_sel <= q_sel_ir0;
        elsif ir = inst_adci or ir = inst_sdbi or ir = inst_smbi or
              ir = inst_adi  or ir = inst_sdi  or ir = inst_smi then
          r_addr_sel <= r_addr_sel_p;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          mem_read <= '1';
          d_sel <= d_sel_alu;
          df_sel <= df_sel_carry;
        elsif ir = inst_shlc or ir = inst_shl then
          d_sel <= d_sel_shifter;
          df_sel <= df_sel_d7;
        elsif i = inst_glo (7 downto 4) or i = inst_ghi (7 downto 4) then
          r_addr_sel <= r_addr_sel_n;
          d_sel <= d_sel_r;
        elsif i = inst_plo (7 downto 4) then
          r_addr_sel <= r_addr_sel_n;
          r_write_data_sel <= r_write_data_sel_d;
          r_write_high <= '0';
          r_write_low <= '1';
        elsif i = inst_phi (7 downto 4) then
          r_addr_sel <= r_addr_sel_n;
          r_write_data_sel <= r_write_data_sel_d;
          r_write_high <= '1';
          r_write_low <= '0';
        elsif i = inst_long_branch_skip (7 downto 4) then
          next_state <= state_execute_2;
          if ir (2) = '0' then
            -- first execute cycle of long branch
            r_addr_sel <= r_addr_sel_p;
            adder_opb_sel <= adder_opb_sel_1;
	    r_write_data_sel <= r_write_data_sel_adder;
            r_write_high <= '1';
            r_write_low <= '1';
            mem_read <= '1';
          else
            -- first execute cycle of long skip
            r_addr_sel <= r_addr_sel_p;
	    if cond_no_skip = '1' then
	      adder_opb_sel <= adder_opb_sel_0;
	    else
	      adder_opb_sel <= adder_opb_sel_1;
            end if;
	    r_write_data_sel <= r_write_data_sel_adder;
            r_write_high <= '1';
            r_write_low <= '1';
          end if;
        elsif i = inst_sep (7 downto 4) then
          xp_sel <= xp_sel_sep;
        elsif i = inst_sex (7 downto 4) then
          xp_sel <= xp_sel_sex;
        elsif ir = inst_ldx then
          r_addr_sel <= r_addr_sel_x;
          mem_read <= '1';
          d_sel <= d_sel_data_in;
        elsif ir = inst_or or ir = inst_and or ir = inst_xor then
          r_addr_sel <= r_addr_sel_x;
          mem_read <= '1';
          d_sel <= d_sel_alu;
        elsif ir = inst_ldi then
          r_addr_sel <= r_addr_sel_p;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          mem_read <= '1';
          d_sel <= d_sel_data_in;
        elsif ir = inst_ori or ir = inst_ani or ir = inst_xri then
          r_addr_sel <= r_addr_sel_p;
          adder_opb_sel <= adder_opb_sel_1;
          r_write_data_sel <= r_write_data_sel_adder;
          r_write_high <= '1';
          r_write_low <= '1';
          mem_read <= '1';
          d_sel <= d_sel_alu;
        else
          null;                         -- illegal instruction, shouldn't happen
        end if;
      when state_execute_2 =>
        sc <= sc_execute;
        if dma_in_req = '1' then
          next_state <= state_dma_in;
        elsif dma_out_req = '1' then
          next_state <= state_dma_out;
        elsif int_req = '1' and ie = '1' then
          next_state <= state_interrupt;
        else
          next_state <= state_fetch;
        end if;
        if ir (2) = '0' then
          -- second execute cycle of long branch
	  r_addr_sel <= r_addr_sel_p;
	  r_write_data_sel <= r_write_data_sel_branch;
          r_write_high <= '1';
          r_write_low <= '1';
          mem_read <= '1';
        else
          -- second execute cycle of long skip
            r_addr_sel <= r_addr_sel_p;
	    if cond_no_skip = '1' then
	      adder_opb_sel <= adder_opb_sel_0;
	    else
	      adder_opb_sel <= adder_opb_sel_1;
            end if;
	    r_write_data_sel <= r_write_data_sel_adder;
            r_write_high <= '1';
            r_write_low <= '1';
        end if;
      when state_dma_in =>
        sc <= sc_dma;
        r_addr_sel <= r_addr_sel_0;
        adder_opb_sel <= adder_opb_sel_1;
        r_write_data_sel <= r_write_data_sel_adder;
        r_write_high <= '1';
        r_write_low <= '1';
        mem_write <= '1';
        if dma_in_req = '1' then
          next_state <= state_dma_in;
        elsif dma_out_req = '1' then
          next_state <= state_dma_out;
        elsif clear = '1' then
          r_write_high <= '0';
          r_write_low <= '0';
          next_state <= state_load;
        elsif int_req = '1' and ie = '1' then
          next_state <= state_interrupt;
        else
          next_state <= state_fetch;
        end if;
      when state_dma_out =>
        sc <= sc_dma;
        r_addr_sel <= r_addr_sel_0;
        adder_opb_sel <= adder_opb_sel_1;
        r_write_data_sel <= r_write_data_sel_adder;
        r_write_high <= '1';
        r_write_low <= '1';
        mem_read <= '1';
        if dma_in_req = '1' then
          next_state <= state_dma_in;
        elsif dma_out_req = '1' then
          next_state <= state_dma_out;
        elsif clear = '1' then
          r_write_high <= '0';
          r_write_low <= '0';
          next_state <= state_load;
        elsif int_req = '1' and ie = '1' then
          next_state <= state_interrupt;
        else
          next_state <= state_fetch;
        end if;
      when state_interrupt =>
        sc <= sc_interrupt;
        if dma_in_req = '1' then
          next_state <= state_dma_in;
        elsif dma_out_req = '1' then
          next_state <= state_dma_out;
        --elsif int_req = '1' and ie = '1' then
        --  next_state <= state_interrupt;
        else
          next_state <= state_fetch;
        end if;
        load_t <= '1';
        xp_sel <= xp_sel_interrupt;
        ie_sel <= ie_sel_0;
      when others =>
        sc <= sc_execute;
        next_state <= state_clear;      -- should never happen
    end case;
  end process control_p;
  
  state_p: process (clk)
  begin
    if rising_edge (clk) then
      if clear = '1' and wait_req = '0' then
        state <= state_clear;
      elsif waiting = '0' then
        state <= next_state;
      end if;
    end if;
  end process state_p;

end rtl;
