library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_demo is
  generic (
    EXTENDED_DEMO : boolean := true
  );
end entity;

architecture test of tb_demo is
  signal clk : std_logic := '0';
  signal clock_enable : std_logic := '1';
  signal rst : std_logic := '1';
  signal trig : std_logic := '0';
  signal init_done, demo_pass, demo_fault : std_logic;
  signal cpu_active, cpu_finished, cpu_cs, cpu_wr, cpu_rdy : std_logic;
  signal cpu_addr, mem_addr : std_logic_vector(15 downto 0);
  signal cpu_wdata, cpu_rdata, mem_wdata : std_logic_vector(7 downto 0);
  signal completed_count : std_logic_vector(7 downto 0);
  signal memory_read_count, memory_write_count : std_logic_vector(15 downto 0);
  signal last_latency, max_latency : std_logic_vector(15 downto 0);
  signal lookup_cycles, ram_access_cycles, replacement_cycles : std_logic_vector(15 downto 0);
  signal read_hit_cycles, write_hit_cycles : std_logic_vector(15 downto 0);
  signal clean_miss_penalty, dirty_miss_penalty : std_logic_vector(15 downto 0);
  signal saw_offset_31 : std_logic;
  signal mem_wr, mem_strb : std_logic;
  signal dbg_accept, dbg_lookup, dbg_done, dbg_replacement_done : std_logic;
  signal dbg_ram_setup, dbg_ram_capture : std_logic;
  signal dbg_case : std_logic_vector(2 downto 0);
  signal dbg_state : std_logic_vector(3 downto 0);
  signal dbg_byte : std_logic_vector(4 downto 0);
  signal dbg_valid, dbg_dirty : std_logic_vector(7 downto 0);
begin
  clocking : process
  begin
    while clock_enable = '1' loop
      clk <= '0'; wait for 5 ns;
      clk <= '1'; wait for 5 ns;
    end loop;
    wait;
  end process;

  dut : entity work.demo_top
    generic map (EXTENDED_DEMO => EXTENDED_DEMO)
    port map (
      clk => clk, rst => rst, trig => trig, init_done => init_done,
      demo_pass => demo_pass, demo_fault => demo_fault,
      cpu_active => cpu_active, cpu_finished => cpu_finished,
      cpu_cs => cpu_cs, cpu_wr => cpu_wr, cpu_addr => cpu_addr,
      cpu_wdata => cpu_wdata, cpu_rdy => cpu_rdy, cpu_rdata => cpu_rdata,
      completed_count => completed_count,
      memory_read_count => memory_read_count,
      memory_write_count => memory_write_count,
      last_latency => last_latency, max_latency => max_latency,
      lookup_cycles => lookup_cycles,
      ram_access_cycles => ram_access_cycles,
      replacement_cycles => replacement_cycles,
      read_hit_cycles => read_hit_cycles,
      write_hit_cycles => write_hit_cycles,
      clean_miss_penalty => clean_miss_penalty,
      dirty_miss_penalty => dirty_miss_penalty,
      saw_offset_31 => saw_offset_31,
      mem_addr => mem_addr, mem_wr => mem_wr, mem_strb => mem_strb,
      mem_wdata => mem_wdata,
      dbg_accept => dbg_accept, dbg_lookup => dbg_lookup,
      dbg_done => dbg_done,
      dbg_replacement_done => dbg_replacement_done,
      dbg_ram_setup => dbg_ram_setup, dbg_ram_capture => dbg_ram_capture,
      dbg_case => dbg_case, dbg_state => dbg_state, dbg_byte => dbg_byte,
      dbg_valid => dbg_valid, dbg_dirty => dbg_dirty
    );

  stimulus : process
  begin
    wait for 40 ns;
    wait until falling_edge(clk);
    rst <= '0';

    -- An early manual edge is ignored; initialization must finish first.
    wait for 100 ns;
    trig <= '1';
    wait for 20 ns;
    trig <= '0';
    wait until init_done = '1';
    wait for 30 ns;
    assert cpu_active = '0' and completed_count = x"00"
      report "pre-initialization trigger was retained" severity failure;

    -- Hold high across all RDY transitions. The edge guard must run the
    -- sequencer once and only once.
    wait until falling_edge(clk);
    trig <= '1';
    wait for 80 us;
    assert demo_fault = '0' report "demo monitor raised a fault" severity failure;
    assert demo_pass = '1' report "extended demo did not pass" severity failure;
    if EXTENDED_DEMO then
      assert cpu_finished = '1' and completed_count = x"10"
        report "extended demo did not finish exactly once" severity failure;
      assert unsigned(memory_read_count) = 352 and unsigned(memory_write_count) = 96
        report "unexpected extended-demo backing-memory strobe totals" severity failure;
    else
      assert cpu_finished = '1' and completed_count = x"08"
        report "course demo did not finish exactly once" severity failure;
      assert unsigned(memory_read_count) = 160 and unsigned(memory_write_count) = 64
        report "unexpected course-demo backing-memory strobe totals" severity failure;
    end if;
    assert saw_offset_31 = '1'
      report "terminal offset 31 was not observed" severity failure;
    report "demo metrics: lookup=" & integer'image(to_integer(unsigned(lookup_cycles))) &
      " ram=" & integer'image(to_integer(unsigned(ram_access_cycles))) &
      " replacement=" & integer'image(to_integer(unsigned(replacement_cycles))) &
      " read-hit=" & integer'image(to_integer(unsigned(read_hit_cycles))) &
      " write-hit=" & integer'image(to_integer(unsigned(write_hit_cycles))) &
      " clean-penalty=" & integer'image(to_integer(unsigned(clean_miss_penalty))) &
      " dirty-penalty=" & integer'image(to_integer(unsigned(dirty_miss_penalty))) severity note;
    assert unsigned(lookup_cycles) = 1 and unsigned(ram_access_cycles) = 1 and
      unsigned(read_hit_cycles) = 3 and unsigned(write_hit_cycles) = 2 and
      unsigned(clean_miss_penalty) = 128 and unsigned(dirty_miss_penalty) = 288
      report "demo timing counters differ from the cycle contract" severity failure;
    if EXTENDED_DEMO then
      assert unsigned(replacement_cycles) = 128
        report "extended replacement interval is incorrect" severity failure;
    else
      assert unsigned(replacement_cycles) = 288
        report "dirty replacement interval is incorrect" severity failure;
    end if;
    report "PASS tb_demo" severity note;
    clock_enable <= '0';
    wait;
  end process;

  watchdog : process
  begin
    wait for 100 us;
    assert demo_pass = '1' report "tb_demo watchdog expired" severity failure;
    wait;
  end process;
end architecture;
