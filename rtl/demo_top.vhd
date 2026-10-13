library ieee;
use ieee.std_logic_1164.all;

-- Board-facing demo harness. clk/rst/trig are the only control inputs;
-- detailed outputs are intended for ChipScope/ILA probe connections.
entity demo_top is
  generic (
    EXTENDED_DEMO : boolean := false
  );
  port (
    clk                  : in  std_logic;
    rst                  : in  std_logic;
    trig                 : in  std_logic;
    init_done            : out std_logic;
    demo_pass            : out std_logic;
    demo_fault           : out std_logic;
    cpu_active           : out std_logic;
    cpu_finished         : out std_logic;
    cpu_cs               : out std_logic;
    cpu_wr               : out std_logic;
    cpu_addr             : out std_logic_vector(15 downto 0);
    cpu_wdata            : out std_logic_vector(7 downto 0);
    cpu_rdy              : out std_logic;
    cpu_rdata            : out std_logic_vector(7 downto 0);
    completed_count      : out std_logic_vector(7 downto 0);
    memory_read_count    : out std_logic_vector(15 downto 0);
    memory_write_count   : out std_logic_vector(15 downto 0);
    last_latency         : out std_logic_vector(15 downto 0);
    max_latency          : out std_logic_vector(15 downto 0);
    lookup_cycles        : out std_logic_vector(15 downto 0);
    ram_access_cycles    : out std_logic_vector(15 downto 0);
    replacement_cycles   : out std_logic_vector(15 downto 0);
    read_hit_cycles      : out std_logic_vector(15 downto 0);
    write_hit_cycles     : out std_logic_vector(15 downto 0);
    clean_miss_penalty   : out std_logic_vector(15 downto 0);
    dirty_miss_penalty   : out std_logic_vector(15 downto 0);
    saw_offset_31        : out std_logic;
    mem_addr             : out std_logic_vector(15 downto 0);
    mem_wr               : out std_logic;
    mem_strb             : out std_logic;
    mem_wdata            : out std_logic_vector(7 downto 0);
    dbg_accept           : out std_logic;
    dbg_lookup           : out std_logic;
    dbg_done             : out std_logic;
    dbg_replacement_done : out std_logic;
    dbg_ram_setup        : out std_logic;
    dbg_ram_capture      : out std_logic;
    dbg_case             : out std_logic_vector(2 downto 0);
    dbg_state            : out std_logic_vector(3 downto 0);
    dbg_byte             : out std_logic_vector(4 downto 0);
    dbg_valid            : out std_logic_vector(7 downto 0);
    dbg_dirty            : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of demo_top is
  signal rst_meta : std_logic := '1';
  signal rst_sync : std_logic := '1';
  signal cpu_trig : std_logic := '0';
  signal trig_previous : std_logic := '0';
  signal cpu_cs_i, cpu_wr_i, cpu_rdy_i : std_logic;
  signal cpu_active_i, cpu_finished_i : std_logic;
  signal cpu_addr_i, mem_addr_i : std_logic_vector(15 downto 0);
  signal cpu_step_i : std_logic_vector(3 downto 0);
  signal cpu_wdata_i, cpu_rdata_i, mem_wdata_i, mem_rdata_i : std_logic_vector(7 downto 0);
  signal mem_wr_i, mem_strb_i, init_done_i, unsupported_i : std_logic;
  signal dbg_accept_i, dbg_lookup_i, dbg_done_i, dbg_replacement_done_i : std_logic;
  signal dbg_ram_setup_i, dbg_ram_capture_i : std_logic;
  signal dbg_case_i : std_logic_vector(2 downto 0);
  signal dbg_state_i : std_logic_vector(3 downto 0);
  signal dbg_byte_i : std_logic_vector(4 downto 0);
  signal dbg_valid_i, dbg_dirty_i : std_logic_vector(7 downto 0);
  signal lookup_cycles_i, ram_access_cycles_i, replacement_cycles_i : std_logic_vector(15 downto 0);
  signal read_hit_cycles_i, write_hit_cycles_i : std_logic_vector(15 downto 0);
  signal clean_miss_penalty_i, dirty_miss_penalty_i : std_logic_vector(15 downto 0);
begin
  process (clk)
  begin
    if rising_edge(clk) then
      rst_meta <= rst;
      rst_sync <= rst_meta;
    end if;
  end process;

  -- One request per manual rising edge. Edges while initialization/cache/CPU
  -- are unavailable are ignored; a held trigger cannot retrigger on RDY.
  process (clk)
  begin
    if rising_edge(clk) then
      cpu_trig <= '0';
      if rst_sync = '1' then
        trig_previous <= '0';
      else
        if trig = '1' and trig_previous = '0' and init_done_i = '1' and
           cpu_rdy_i = '1' and cpu_active_i = '0' and cpu_finished_i = '0' then
          cpu_trig <= '1';
        end if;
        trig_previous <= trig;
      end if;
    end if;
  end process;

  cpu_inst : entity work.demo_cpu
    generic map (EXTENDED => EXTENDED_DEMO)
    port map (
      clk => clk, rst => rst_sync, trig => cpu_trig,
      cpu_rdy => cpu_rdy_i, cpu_rdata => cpu_rdata_i,
      cpu_cs => cpu_cs_i, cpu_wr => cpu_wr_i,
      cpu_addr => cpu_addr_i, cpu_wdata => cpu_wdata_i,
      step => cpu_step_i, active => cpu_active_i, finished => cpu_finished_i
    );

  cache_inst : entity work.cache_system
    port map (
      clk => clk, rst => rst_sync,
      cpu_cs => cpu_cs_i, cpu_wr => cpu_wr_i,
      cpu_addr => cpu_addr_i, cpu_wdata => cpu_wdata_i,
      cpu_rdy => cpu_rdy_i, cpu_rdata => cpu_rdata_i,
      mem_addr => mem_addr_i, mem_wr => mem_wr_i, mem_strb => mem_strb_i,
      mem_wdata => mem_wdata_i, mem_rdata => mem_rdata_i,
      dbg_accept => dbg_accept_i, dbg_lookup => dbg_lookup_i,
      dbg_done => dbg_done_i,
      dbg_replacement_done => dbg_replacement_done_i,
      dbg_ram_setup => dbg_ram_setup_i, dbg_ram_capture => dbg_ram_capture_i,
      dbg_case => dbg_case_i, dbg_state => dbg_state_i, dbg_byte => dbg_byte_i,
      dbg_valid => dbg_valid_i, dbg_dirty => dbg_dirty_i
    );

  memory_inst : entity work.demo_memory
    port map (
      clk => clk, rst => rst_sync, mem_addr => mem_addr_i,
      mem_wr => mem_wr_i, mem_strb => mem_strb_i,
      mem_wdata => mem_wdata_i, mem_rdata => mem_rdata_i,
      init_done => init_done_i, unsupported => unsupported_i
    );

  monitor_inst : entity work.demo_monitor
    generic map (EXTENDED => EXTENDED_DEMO)
    port map (
      clk => clk, rst => rst_sync, init_done => init_done_i,
      memory_unsupported => unsupported_i,
      cpu_rdy => cpu_rdy_i, cpu_rdata => cpu_rdata_i, cpu_wr => cpu_wr_i,
      cpu_step => cpu_step_i, cpu_finished => cpu_finished_i,
      mem_addr => mem_addr_i, mem_wr => mem_wr_i, mem_strb => mem_strb_i,
      mem_wdata => mem_wdata_i,
      dbg_accept => dbg_accept_i, dbg_done => dbg_done_i,
      dbg_lookup => dbg_lookup_i,
      dbg_replacement_done => dbg_replacement_done_i,
      dbg_ram_setup => dbg_ram_setup_i, dbg_ram_capture => dbg_ram_capture_i,
      dbg_case => dbg_case_i,
      demo_pass => demo_pass, demo_fault => demo_fault,
      completed_count => completed_count,
      memory_read_count => memory_read_count,
      memory_write_count => memory_write_count,
      last_latency => last_latency, max_latency => max_latency,
      lookup_cycles => lookup_cycles_i,
      ram_access_cycles => ram_access_cycles_i,
      replacement_cycles => replacement_cycles_i,
      read_hit_cycles => read_hit_cycles_i,
      write_hit_cycles => write_hit_cycles_i,
      clean_miss_penalty => clean_miss_penalty_i,
      dirty_miss_penalty => dirty_miss_penalty_i,
      saw_offset_31 => saw_offset_31
    );

  -- Export only controller-defined information; no board pins or generated
  -- ChipScope cores are presumed by this source tree.
  init_done <= init_done_i;
  cpu_active <= cpu_active_i;
  cpu_finished <= cpu_finished_i;
  cpu_cs <= cpu_cs_i;
  cpu_wr <= cpu_wr_i;
  cpu_addr <= cpu_addr_i;
  cpu_wdata <= cpu_wdata_i;
  cpu_rdy <= cpu_rdy_i;
  cpu_rdata <= cpu_rdata_i;
  mem_addr <= mem_addr_i;
  mem_wr <= mem_wr_i;
  mem_strb <= mem_strb_i;
  mem_wdata <= mem_wdata_i;
  lookup_cycles <= lookup_cycles_i;
  ram_access_cycles <= ram_access_cycles_i;
  replacement_cycles <= replacement_cycles_i;
  read_hit_cycles <= read_hit_cycles_i;
  write_hit_cycles <= write_hit_cycles_i;
  clean_miss_penalty <= clean_miss_penalty_i;
  dirty_miss_penalty <= dirty_miss_penalty_i;
  dbg_accept <= dbg_accept_i;
  dbg_lookup <= dbg_lookup_i;
  dbg_done <= dbg_done_i;
  dbg_replacement_done <= dbg_replacement_done_i;
  dbg_ram_setup <= dbg_ram_setup_i;
  dbg_ram_capture <= dbg_ram_capture_i;
  dbg_case <= dbg_case_i;
  dbg_state <= dbg_state_i;
  dbg_byte <= dbg_byte_i;
  dbg_valid <= dbg_valid_i;
  dbg_dirty <= dbg_dirty_i;
end architecture;
