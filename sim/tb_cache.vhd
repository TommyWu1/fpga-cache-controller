library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cache_tb_pkg.all;

entity tb_cache is
  generic (REGISTERED_MEMORY : boolean := false);
end entity;

architecture test of tb_cache is
  constant PERIOD : time := 10 ns;
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal cpu_cs, cpu_wr : std_logic := '0';
  signal cpu_addr : std_logic_vector(15 downto 0) := (others => '0');
  signal cpu_wdata, cpu_rdata : std_logic_vector(7 downto 0) := (others => '0');
  signal cpu_rdy : std_logic;
  signal mem_addr : std_logic_vector(15 downto 0);
  signal mem_wr, mem_strb : std_logic;
  signal mem_wdata, mem_rdata : std_logic_vector(7 downto 0);
  signal dbg_accept, dbg_lookup, dbg_done, dbg_replacement_done : std_logic;
  signal dbg_ram_setup, dbg_ram_capture : std_logic;
  signal dbg_case : std_logic_vector(2 downto 0);
  signal dbg_state : std_logic_vector(3 downto 0);
  signal dbg_byte : std_logic_vector(4 downto 0);
  signal dbg_valid, dbg_dirty : std_logic_vector(7 downto 0);
  signal mem_error : std_logic;
  signal reads, writes : natural;
  signal accept_events, lookup_events, done_events : natural := 0;
  signal repl_events, setup_events, capture_events : natural := 0;
  signal pulse_events : natural := 0;
  signal observed_addr : std_logic_vector(15 downto 0) := (others => '0');
  signal observed_wr : std_logic := '0';
  signal observed_data : std_logic_vector(7 downto 0) := (others => '0');
  signal old_pulse : std_logic := '0';
  type addr_log_t is array (0 to 131071) of std_logic_vector(15 downto 0);
  type data_log_t is array (0 to 131071) of std_logic_vector(7 downto 0);
  type dir_log_t is array (0 to 131071) of std_logic;
  signal addr_log : addr_log_t;
  signal data_log : data_log_t;
  signal dir_log : dir_log_t;
begin
  clk <= not clk after PERIOD / 2;

  dut : entity work.cache_system
    port map (
      clk => clk, rst => rst, cpu_cs => cpu_cs, cpu_wr => cpu_wr,
      cpu_addr => cpu_addr, cpu_wdata => cpu_wdata, cpu_rdy => cpu_rdy,
      cpu_rdata => cpu_rdata, mem_addr => mem_addr, mem_wr => mem_wr,
      mem_strb => mem_strb, mem_wdata => mem_wdata, mem_rdata => mem_rdata,
      dbg_accept => dbg_accept, dbg_lookup => dbg_lookup, dbg_done => dbg_done,
      dbg_replacement_done => dbg_replacement_done,
      dbg_ram_setup => dbg_ram_setup, dbg_ram_capture => dbg_ram_capture,
      dbg_case => dbg_case, dbg_state => dbg_state, dbg_byte => dbg_byte,
      dbg_valid => dbg_valid, dbg_dirty => dbg_dirty
    );

  memory_model : entity work.main_memory_model
    generic map (REGISTERED_READ => REGISTERED_MEMORY)
    port map (clk => clk, rst => rst, mem_addr => mem_addr, mem_wr => mem_wr,
      mem_strb => mem_strb, mem_wdata => mem_wdata, mem_rdata => mem_rdata,
      protocol_err => mem_error, read_count => reads, write_count => writes);

  event_monitor : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        accept_events <= 0; lookup_events <= 0; done_events <= 0;
        repl_events <= 0; setup_events <= 0; capture_events <= 0;
        pulse_events <= 0; old_pulse <= '0';
      else
        if dbg_accept = '1' then accept_events <= accept_events + 1; end if;
        if dbg_lookup = '1' then lookup_events <= lookup_events + 1; end if;
        if dbg_done = '1' then done_events <= done_events + 1; end if;
        if dbg_replacement_done = '1' then repl_events <= repl_events + 1; end if;
        if dbg_ram_setup = '1' then setup_events <= setup_events + 1; end if;
        if dbg_ram_capture = '1' then capture_events <= capture_events + 1; end if;
        if mem_strb = '1' then
          addr_log(pulse_events) <= mem_addr;
          data_log(pulse_events) <= mem_wdata;
          dir_log(pulse_events) <= mem_wr;
          pulse_events <= pulse_events + 1;
          assert old_pulse = '0' report "memory strobe exceeded one clock" severity error;
          assert mem_addr = observed_addr and mem_wr = observed_wr and
                 (mem_wr = '0' or mem_wdata = observed_data)
            report "memory address/direction/data changed between setup and strobe" severity error;
        end if;
        old_pulse <= mem_strb;
        observed_addr <= mem_addr;
        observed_wr <= mem_wr;
        observed_data <= mem_wdata;
      end if;
    end if;
  end process;

  stimulus : process
    type arch_t is array (0 to 65535) of std_logic_vector(7 downto 0);
    variable arch : arch_t;
    variable tx_before, rd_before, wr_before : natural;
    variable expected : std_logic_vector(7 downto 0);
    variable a, tagv, idx, offv, k, c : natural;
    variable seed : unsigned(31 downto 0) := x"13579BDF";
    variable random_addr : natural;
    variable random_data : std_logic_vector(7 downto 0);
    variable last_latency, log_before : natural := 0;

    procedure wait_ready is
    begin
      while cpu_rdy /= '1' loop
        wait until rising_edge(clk);
        wait for 1 ns;
      end loop;
    end procedure;

    procedure transact(constant addr_i : in natural;
                       constant wr_i : in std_logic;
                       constant data_i : in std_logic_vector(7 downto 0);
                       constant change_while_busy : in boolean := true) is
      variable edge_count : natural := 0;
      variable completed : boolean := false;
    begin
      wait_ready;
      wait until falling_edge(clk);
      cpu_addr <= std_logic_vector(to_unsigned(addr_i, 16));
      cpu_wr <= wr_i;
      cpu_wdata <= data_i;
      cpu_cs <= '1';
      for q in 1 to 4 loop
        wait until rising_edge(clk);
        edge_count := edge_count + 1;
        wait for 1 ns;
        if not completed and cpu_rdy = '1' then
          last_latency := edge_count - 1;
          completed := true;
        end if;
      end loop;
      wait until falling_edge(clk);
      cpu_cs <= '0';
      if change_while_busy then
        cpu_addr <= not std_logic_vector(to_unsigned(addr_i, 16));
        cpu_wr <= not wr_i;
        cpu_wdata <= not data_i;
      end if;
      while not completed loop
        wait until rising_edge(clk);
        edge_count := edge_count + 1;
        wait for 1 ns;
        if cpu_rdy = '1' then
          last_latency := edge_count - 1;
          completed := true;
        end if;
      end loop;
    end procedure;

    procedure read_check(constant addr_i : in natural) is
    begin
      expected := arch(addr_i);
      transact(addr_i, '0', x"00");
      assert cpu_rdata = expected
        report "read data mismatch at address " & integer'image(addr_i) severity error;
    end procedure;

    procedure write_check(constant addr_i : in natural;
                          constant value_i : in std_logic_vector(7 downto 0)) is
    begin
      transact(addr_i, '1', value_i);
      arch(addr_i) := value_i;
    end procedure;
  begin
    for i in 0 to 65535 loop arch(i) := pattern_byte(i); end loop;
    wait for 5 * PERIOD;
    wait until falling_edge(clk);
    rst <= '0';
    wait_ready;

    -- Reset aborts an in-flight clean refill; the next request must start cleanly.
    wait until falling_edge(clk);
    cpu_addr <= x"E7E7"; cpu_wr <= '0'; cpu_wdata <= x"00"; cpu_cs <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk); cpu_cs <= '0';
    for q in 1 to 8 loop wait until rising_edge(clk); end loop;
    wait until falling_edge(clk); rst <= '1';
    for q in 1 to 2 loop wait until rising_edge(clk); end loop;
    wait until falling_edge(clk); rst <= '0';
    wait_ready;
    read_check(16#E7E7#);
    assert last_latency = 131 and dbg_case = "010"
      report "clean read-miss latency/classification mismatch" severity error;

    -- A busy strobe is ignored, and a CS held high through completion is not replayed.
    tx_before := accept_events;
    wait until falling_edge(clk);
    cpu_addr <= x"E8E8"; cpu_wr <= '0'; cpu_wdata <= x"00"; cpu_cs <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk); cpu_cs <= '0';
    wait until rising_edge(clk);
    wait until falling_edge(clk); cpu_cs <= '1';
    wait until rising_edge(clk);
    -- Keep the second high level held until the initial miss has completed.
    wait_ready;
    for q in 1 to 4 loop wait until rising_edge(clk); end loop;
    wait for 1 ns;
    assert accept_events = tx_before + 1
      report "held/busy CS caused a duplicate or delayed acceptance" severity error;
    wait until falling_edge(clk); cpu_cs <= '0';
    wait_ready;
    wait for 1 ns;

    -- Refill all 32 byte lanes and replay a write after the live CPU pins change.
    tx_before := accept_events; rd_before := reads; wr_before := writes;
    log_before := pulse_events;
    write_check(request_address(16#11#, 0, 31), x"D3");
    assert last_latency = 130 and dbg_case = "011"
      report "clean write-miss latency/classification mismatch" severity error;
    assert reads = rd_before + 32 and writes = wr_before
      report "clean write miss must perform exactly 32 refill reads" severity error;
    for byte_index in 0 to 31 loop
      assert addr_log(log_before + byte_index) = std_logic_vector(to_unsigned(16#1100# + byte_index, 16)) and
             dir_log(log_before + byte_index) = '0'
        report "clean refill address/direction sequence mismatch" severity error;
    end loop;
    assert accept_events = tx_before + 1 report "request was accepted more than once" severity error;
    assert dbg_dirty(0) = '1' and dbg_valid(0) = '1'
      report "write replay did not leave line valid and dirty" severity error;

    -- Both hit paths, including a read that returns the committed SRAM byte.
    rd_before := reads; wr_before := writes;
    read_check(request_address(16#11#, 0, 31));
    assert last_latency = 3 and dbg_case = "000"
      report "read-hit latency/classification mismatch" severity error;
    assert reads = rd_before and writes = wr_before report "read hit accessed main memory" severity error;
    write_check(request_address(16#11#, 0, 0), x"A6");
    assert last_latency = 2 and dbg_case = "001"
      report "write-hit latency/classification mismatch" severity error;
    assert reads = rd_before and writes = wr_before report "write hit accessed main memory" severity error;
    read_check(request_address(16#11#, 0, 0));

    -- Same index, different tag forces 32 old-tag writes followed by 32 refill reads.
    rd_before := reads; wr_before := writes;
    log_before := pulse_events;
    read_check(request_address(16#91#, 0, 7));
    assert last_latency = 291 and dbg_case = "100"
      report "dirty read-miss latency/classification mismatch" severity error;
    assert reads = rd_before + 32 and writes = wr_before + 32
      report "dirty replacement did not write back and refill exactly 32 bytes" severity error;
    for byte_index in 0 to 31 loop
      assert addr_log(log_before + byte_index) = std_logic_vector(to_unsigned(16#1100# + byte_index, 16)) and
             dir_log(log_before + byte_index) = '1' and
             data_log(log_before + byte_index) = arch(16#1100# + byte_index)
        report "dirty victim write-back sequence/data mismatch" severity error;
      assert addr_log(log_before + 32 + byte_index) = std_logic_vector(to_unsigned(16#9100# + byte_index, 16)) and
             dir_log(log_before + 32 + byte_index) = '0'
        report "replacement refill address/direction sequence mismatch" severity error;
    end loop;
    assert dbg_valid(0) = '1' and dbg_dirty(0) = '0'
      report "refilled line metadata is not valid/clean" severity error;
    -- Evict the 0x91 block with a clean line, then prove dirty bytes reached old memory.
    read_check(request_address(16#12#, 0, 3));
    read_check(request_address(16#11#, 0, 31));
    read_check(request_address(16#11#, 0, 0));

    -- Dirty write-miss case: the original write must replay after write-back/refill.
    write_check(request_address(16#92#, 0, 5), x"7A");
    log_before := pulse_events;
    write_check(request_address(16#A2#, 0, 10), x"6B");
    assert last_latency = 290 and dbg_case = "101"
      report "dirty write-miss latency/classification mismatch" severity error;
    for byte_index in 0 to 31 loop
      assert addr_log(log_before + byte_index) = std_logic_vector(to_unsigned(16#9200# + byte_index, 16)) and
             dir_log(log_before + byte_index) = '1' and
             data_log(log_before + byte_index) = arch(16#9200# + byte_index)
        report "dirty write-miss victim address/data mismatch" severity error;
      assert addr_log(log_before + 32 + byte_index) = std_logic_vector(to_unsigned(16#A200# + byte_index, 16)) and
             dir_log(log_before + 32 + byte_index) = '0'
        report "dirty write-miss refill sequence mismatch" severity error;
    end loop;
    read_check(request_address(16#B2#, 0, 0));
    read_check(request_address(16#A2#, 0, 10));

    -- Cover every index and offset. Distinct tags avoid accidental aliases.
    for ix in 0 to 7 loop
      tagv := 16#30# + ix;
      for ov in 0 to 31 loop
        read_check(request_address(tagv, ix, ov));
      end loop;
    end loop;

    -- Dirty eviction recovery at offset 0 and 31 for every direct-mapped index.
    for ix in 0 to 7 loop
      tagv := 16#50# + ix;
      write_check(request_address(tagv, ix, 0), std_logic_vector(to_unsigned(16#80# + ix, 8)));
      write_check(request_address(tagv, ix, 31), std_logic_vector(to_unsigned(16#C0# + ix, 8)));
      read_check(request_address(tagv + 16, ix, 9));
      read_check(request_address(tagv, ix, 0));
      read_check(request_address(tagv, ix, 31));
    end loop;

    -- Deterministic xorshift stream stresses replacements and request capture.
    for n in 0 to 999 loop
      seed := seed xor shift_left(seed, 13);
      seed := seed xor shift_right(seed, 17);
      seed := seed xor shift_left(seed, 5);
      random_addr := to_integer(seed(15 downto 0));
      random_data := std_logic_vector(seed(23 downto 16));
      if seed(31) = '1' then write_check(random_addr, random_data);
      else read_check(random_addr); end if;
    end loop;

    wait until rising_edge(clk);
    wait for 1 ns;
    assert accept_events = lookup_events and lookup_events = done_events
      report "accept/lookup/done event counts differ: " & integer'image(accept_events) & "/" &
        integer'image(lookup_events) & "/" & integer'image(done_events) severity error;
    assert mem_error = '0' report "main-memory protocol monitor reported an error" severity error;
    assert pulse_events = reads + writes report "strobe event count disagrees with memory model" severity error;
    report "PASS tb_cache: registered-memory=" & boolean'image(REGISTERED_MEMORY) & "; " & integer'image(accept_events) & " transactions, " &
      integer'image(reads) & " memory reads, " & integer'image(writes) & " writes" severity note;
    wait;
  end process;

  watchdog : process
  begin
    wait for 10 ms;
    assert false report "tb_cache watchdog expired" severity failure;
  end process;
end architecture;
