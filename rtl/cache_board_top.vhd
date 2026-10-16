library ieee;
use ieee.std_logic_1164.all;
use work.all;

-- Only the board oscillator is a physical port. Generate the three ChipScope
-- cores with the names and widths in docs/chipscope.md before implementation.
entity cache_board_top is
  generic (EXTENDED_DEMO : boolean := false);
  port (clk : in std_logic);
end entity;

architecture rtl of cache_board_top is
  component cache_icon is
    port (CONTROL0, CONTROL1 : inout std_logic_vector(35 downto 0));
  end component;
  component cache_ila is
    port (CONTROL : inout std_logic_vector(35 downto 0);
          CLK : in std_logic;
          TRIG0 : in std_logic_vector(127 downto 0));
  end component;
  component cache_vio is
    port (CONTROL : inout std_logic_vector(35 downto 0);
          CLK : in std_logic;
          SYNC_IN : in std_logic_vector(191 downto 0);
          SYNC_OUT : out std_logic_vector(1 downto 0));
  end component;
  attribute box_type : string;
  attribute box_type of cache_icon, cache_ila, cache_vio : component is "black_box";

  signal control_ila, control_vio : std_logic_vector(35 downto 0);
  signal probes : std_logic_vector(127 downto 0);
  signal status : std_logic_vector(191 downto 0);
  signal controls : std_logic_vector(1 downto 0);
begin
  icon_inst : cache_icon
    port map (CONTROL0 => control_ila, CONTROL1 => control_vio);
  ila_inst : cache_ila
    port map (CONTROL => control_ila, CLK => clk, TRIG0 => probes);
  vio_inst : cache_vio
    port map (CONTROL => control_vio, CLK => clk,
              SYNC_IN => status, SYNC_OUT => controls);

  demo_inst : entity work.demo_top
    generic map (EXTENDED_DEMO => EXTENDED_DEMO)
    port map (
      clk => clk, rst => controls(0), trig => controls(1),
      cpu_addr => probes(15 downto 0),
      cpu_wdata => probes(23 downto 16),
      cpu_rdata => probes(31 downto 24),
      mem_addr => probes(47 downto 32),
      mem_wdata => probes(55 downto 48),
      cpu_cs => probes(56), cpu_wr => probes(57), cpu_rdy => probes(58),
      mem_wr => probes(59), mem_strb => probes(60),
      dbg_accept => probes(61), dbg_lookup => probes(62),
      dbg_done => probes(63), dbg_replacement_done => probes(64),
      dbg_ram_setup => probes(65), dbg_ram_capture => probes(66),
      dbg_case => probes(69 downto 67), dbg_state => probes(73 downto 70),
      dbg_byte => probes(78 downto 74), dbg_valid => probes(86 downto 79),
      dbg_dirty => probes(94 downto 87), cpu_active => probes(95),
      cpu_finished => probes(96), init_done => probes(97),
      demo_pass => probes(98), demo_fault => probes(99),
      saw_offset_31 => probes(100),
      completed_count => status(7 downto 0),
      memory_read_count => status(23 downto 8),
      memory_write_count => status(39 downto 24),
      last_latency => status(55 downto 40), max_latency => status(71 downto 56),
      lookup_cycles => status(87 downto 72),
      ram_access_cycles => status(103 downto 88),
      replacement_cycles => status(119 downto 104),
      read_hit_cycles => status(135 downto 120),
      write_hit_cycles => status(151 downto 136),
      clean_miss_penalty => status(167 downto 152),
      dirty_miss_penalty => status(183 downto 168)
    );

  probes(127 downto 101) <= (others => '0');
  status(184) <= probes(97);  -- init_done
  status(185) <= probes(98);  -- demo_pass
  status(186) <= probes(99);  -- demo_fault
  status(187) <= probes(96);  -- cpu_finished
  status(188) <= probes(58);  -- cpu_rdy
  status(189) <= probes(100); -- saw_offset_31
  status(190) <= probes(95);  -- cpu_active
  status(191) <= '0';
end architecture;
