library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_course_cpu is end entity;

architecture test of tb_course_cpu is
  constant PERIOD : time := 10 ns;
  signal clk, rst, trig : std_logic := '0';
  signal cpu_addr : std_logic_vector(15 downto 0);
  signal cpu_wr, cpu_cs : std_logic;
  signal cpu_wdata : std_logic_vector(7 downto 0);
  signal cpu_rdy : std_logic;
  signal cpu_rdata : std_logic_vector(7 downto 0);
  signal mem_addr : std_logic_vector(15 downto 0);
  signal mem_wr, mem_strb : std_logic;
  signal mem_wdata, mem_rdata : std_logic_vector(7 downto 0);
  signal da, dl, dd, dr, ds, dc : std_logic;
  signal dcase : std_logic_vector(2 downto 0);
  signal dstate : std_logic_vector(3 downto 0);
  signal dbyte : std_logic_vector(4 downto 0);
  signal dvalid, ddirty : std_logic_vector(7 downto 0);
  signal mem_error : std_logic;
  signal reads, writes : natural;
begin
  clk <= not clk after PERIOD / 2;
  cpu : entity work.CPU_gen port map (clk => clk, rst => rst, trig => trig,
      Address => cpu_addr, wr_rd => cpu_wr, cs => cpu_cs, DOut => cpu_wdata);
  dut : entity work.cache_system port map (
      clk => clk, rst => rst, cpu_cs => cpu_cs, cpu_wr => cpu_wr,
      cpu_addr => cpu_addr, cpu_wdata => cpu_wdata, cpu_rdy => cpu_rdy,
      cpu_rdata => cpu_rdata, mem_addr => mem_addr, mem_wr => mem_wr,
      mem_strb => mem_strb, mem_wdata => mem_wdata, mem_rdata => mem_rdata,
      dbg_accept => da, dbg_lookup => dl, dbg_done => dd,
      dbg_replacement_done => dr, dbg_ram_setup => ds, dbg_ram_capture => dc,
      dbg_case => dcase, dbg_state => dstate, dbg_byte => dbyte,
      dbg_valid => dvalid, dbg_dirty => ddirty);
  memory_model : entity work.main_memory_model generic map (INIT_FF => true) port map (clk => clk, rst => rst,
      mem_addr => mem_addr, mem_wr => mem_wr, mem_strb => mem_strb,
      mem_wdata => mem_wdata, mem_rdata => mem_rdata, protocol_err => mem_error,
      read_count => reads, write_count => writes);

  stimulus : process
    type addr_vec_t is array (0 to 7) of std_logic_vector(15 downto 0);
    type data_vec_t is array (0 to 7) of std_logic_vector(7 downto 0);
    type bit_vec_t is array (0 to 7) of std_logic;
    constant addresses : addr_vec_t := (x"1100", x"1102", x"1100", x"1102", x"3346", x"4444", x"5504", x"6606");
    constant data_values : data_vec_t := (x"AA", x"BB", x"00", x"00", x"00", x"00", x"CC", x"00");
    constant write_values : bit_vec_t := ('1', '1', '0', '0', '0', '0', '1', '0');
    variable sampled_addr : std_logic_vector(15 downto 0);
    variable sampled_wr : std_logic;
    variable sampled_data : std_logic_vector(7 downto 0);
  begin
    rst <= '1';
    wait for 5 * PERIOD;
    wait until falling_edge(clk); rst <= '0';
    for v in 0 to 7 loop
      while cpu_rdy /= '1' loop wait until rising_edge(clk); end loop;
      wait until falling_edge(clk); trig <= '1';
      wait until falling_edge(clk); trig <= '0';
      wait until cpu_cs = '1';
      wait for 1 ns;
      sampled_addr := cpu_addr; sampled_wr := cpu_wr; sampled_data := cpu_wdata;
      assert sampled_addr = addresses(v) report "course CPU address vector mismatch at step " & integer'image(v) &
        ": got " & integer'image(to_integer(unsigned(sampled_addr))) &
        ", expected " & integer'image(to_integer(unsigned(addresses(v)))) severity error;
      assert sampled_wr = write_values(v) report "course CPU direction mismatch at step " & integer'image(v) severity error;
      if sampled_wr = '1' then
        assert sampled_data = data_values(v) report "course CPU write-data vector mismatch at step " & integer'image(v) severity error;
      end if;
      wait until cpu_cs = '0';
      while cpu_rdy /= '1' loop wait until rising_edge(clk); end loop;
      wait for 1 ns;
      if v = 2 then assert cpu_rdata = x"AA" report "course vector 2 expected 0xAA" severity error; end if;
      if v = 3 then assert cpu_rdata = x"BB" report "course vector 3 expected 0xBB" severity error; end if;
      if v = 4 or v = 5 or v = 7 then
        assert cpu_rdata = x"FF" report "course clean-refill read expected 0xFF" severity error;
      end if;
    end loop;
    assert mem_error = '0' report "course sequence memory protocol failure" severity error;
    report "PASS tb_course_cpu: all eight preserved course vectors" severity note;
    wait;
  end process;

  watchdog : process
  begin
    wait for 10 ms;
    assert false report "tb_course_cpu watchdog expired" severity failure;
  end process;
end architecture;
