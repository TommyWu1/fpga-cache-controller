library ieee;
use ieee.std_logic_1164.all;

entity cache_system is
  port (
    clk, rst : in std_logic;
    cpu_cs, cpu_wr : in std_logic;
    cpu_addr : in std_logic_vector(15 downto 0);
    cpu_wdata : in std_logic_vector(7 downto 0);
    cpu_rdy : out std_logic;
    cpu_rdata : out std_logic_vector(7 downto 0);
    mem_addr : out std_logic_vector(15 downto 0);
    mem_wr, mem_strb : out std_logic;
    mem_wdata : out std_logic_vector(7 downto 0);
    mem_rdata : in std_logic_vector(7 downto 0);
    dbg_accept, dbg_lookup, dbg_done, dbg_replacement_done : out std_logic;
    dbg_ram_setup, dbg_ram_capture : out std_logic;
    dbg_case : out std_logic_vector(2 downto 0);
    dbg_state : out std_logic_vector(3 downto 0);
    dbg_byte : out std_logic_vector(4 downto 0);
    dbg_valid, dbg_dirty : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of cache_system is
  signal ram_addr : std_logic_vector(7 downto 0);
  signal ram_we, ram_clk : std_logic;
  signal ram_wdata, ram_rdata : std_logic_vector(7 downto 0);
begin
  ram_clk <= clk;

  controller : entity work.cache_controller
    port map (
      clk => clk, rst => rst,
      cpu_cs => cpu_cs, cpu_wr => cpu_wr, cpu_addr => cpu_addr,
      cpu_wdata => cpu_wdata, cpu_rdy => cpu_rdy, cpu_rdata => cpu_rdata,
      ram_addr => ram_addr, ram_we => ram_we, ram_wdata => ram_wdata,
      ram_rdata => ram_rdata,
      mem_addr => mem_addr, mem_wr => mem_wr, mem_strb => mem_strb,
      mem_wdata => mem_wdata, mem_rdata => mem_rdata,
      dbg_accept => dbg_accept, dbg_lookup => dbg_lookup, dbg_done => dbg_done,
      dbg_replacement_done => dbg_replacement_done,
      dbg_ram_setup => dbg_ram_setup, dbg_ram_capture => dbg_ram_capture,
      dbg_case => dbg_case, dbg_state => dbg_state, dbg_byte => dbg_byte,
      dbg_valid => dbg_valid, dbg_dirty => dbg_dirty
    );

  data_ram : entity work.cache_ram
    port map (
      clk => ram_clk, we => ram_we, addr => ram_addr,
      wdata => ram_wdata, rdata => ram_rdata
    );
end architecture;
