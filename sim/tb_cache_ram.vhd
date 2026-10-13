library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_cache_ram is end entity;

architecture test of tb_cache_ram is
  signal clk : std_logic := '0';
  signal we : std_logic := '0';
  signal addr : std_logic_vector(7 downto 0) := (others => '0');
  signal wdata, rdata : std_logic_vector(7 downto 0) := (others => '0');
begin
  clk <= not clk after 5 ns;
  dut : entity work.cache_ram port map (clk => clk, we => we, addr => addr, wdata => wdata, rdata => rdata);

  stimulus : process
  begin
    wait until falling_edge(clk);
    addr <= x"A5"; wdata <= x"3C"; we <= '1';
    wait until rising_edge(clk); wait for 1 ns;
    assert rdata = x"3C" report "cache RAM write must be visible after its rising edge" severity error;
    wait until falling_edge(clk);
    we <= '0'; addr <= x"A5";
    wait until rising_edge(clk); wait for 1 ns;
    assert rdata = x"3C" report "cache RAM read is not synchronous/readable" severity error;
    wait until falling_edge(clk);
    addr <= x"5A"; wdata <= x"E7"; we <= '1';
    wait until rising_edge(clk); wait for 1 ns;
    assert rdata = x"E7" report "cache RAM write-first behavior failed" severity error;
    report "PASS tb_cache_ram" severity note;
    wait;
  end process;

  watchdog : process
  begin
    wait for 1 us;
    assert false report "tb_cache_ram watchdog expired" severity failure;
  end process;
end architecture;
