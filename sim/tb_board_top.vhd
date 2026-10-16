library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.chipscope_tb_pkg.all;

entity tb_board_top is
  generic (EXTENDED_DEMO : boolean := false);
end entity;

architecture test of tb_board_top is
  signal clk : std_logic := '0';
  signal clock_enable : boolean := true;
begin
  clocking : process
  begin
    while clock_enable loop
      clk <= '0'; wait for 5 ns;
      clk <= '1'; wait for 5 ns;
    end loop;
    wait;
  end process;

  dut : entity work.cache_board_top
    generic map (EXTENDED_DEMO => EXTENDED_DEMO)
    port map (clk => clk);

  stimulus : process
    variable read_hits : natural := 0;
    variable write_strobes, read_strobes : natural := 0;
    variable complete_before : std_logic_vector(7 downto 0);
  begin
    vio_outputs <= "01"; -- reset=1, trigger=0
    wait for 60 ns;
    assert vio_inputs(184) = '0'
      report "memory initialized while reset was held" severity failure;
    vio_outputs <= "00";
    wait until vio_inputs(184) = '1';
    wait for 30 ns;
    assert vio_inputs(188) = '1' and vio_inputs(7 downto 0) = x"00"
      report "board wrapper did not expose ready/zero counts" severity failure;
    wait until falling_edge(clk);
    vio_outputs <= "10"; -- one held trigger starts the full sequence
    loop
      wait until rising_edge(clk);
      wait for 1 ns;
      assert vio_inputs(186) = '0'
        report "board wrapper exposed demo fault" severity failure;
      if ila_inputs(60) = '1' then
        if ila_inputs(59) = '1' then write_strobes := write_strobes + 1;
        else read_strobes := read_strobes + 1; end if;
      end if;
      if ila_inputs(63) = '1' and ila_inputs(57) = '0' then
        if ila_inputs(15 downto 0) = x"1100" then
          assert ila_inputs(31 downto 24) = x"AA"
            report "ILA probe did not expose saved AA readback" severity failure;
          read_hits := read_hits + 1;
        end if;
      end if;
      exit when vio_inputs(185) = '1';
    end loop;
    assert read_hits > 0 and vio_inputs(189) = '1'
      report "board probes missed readback or terminal offset" severity failure;
    if EXTENDED_DEMO then
      assert vio_inputs(7 downto 0) = x"10" and
             unsigned(vio_inputs(23 downto 8)) = 352 and
             unsigned(vio_inputs(39 downto 24)) = 96 and
             read_strobes = 352 and write_strobes = 96
        report "extended board probe totals incorrect" severity failure;
    else
      assert vio_inputs(7 downto 0) = x"08" and
             unsigned(vio_inputs(23 downto 8)) = 160 and
             unsigned(vio_inputs(39 downto 24)) = 64 and
             read_strobes = 160 and write_strobes = 64
        report "course board probe totals incorrect" severity failure;
    end if;
    assert unsigned(vio_inputs(87 downto 72)) = 1 and
           unsigned(vio_inputs(103 downto 88)) = 1 and
           unsigned(vio_inputs(135 downto 120)) = 3 and
           unsigned(vio_inputs(151 downto 136)) = 2 and
           unsigned(vio_inputs(167 downto 152)) = 128 and
           unsigned(vio_inputs(183 downto 168)) = 288
      report "VIO timing probe mapping incorrect" severity failure;
    complete_before := vio_inputs(7 downto 0);
    wait for 1 us;
    assert vio_inputs(7 downto 0) = complete_before and vio_inputs(185) = '1'
      report "held trigger restarted completed board run" severity failure;
    report "PASS tb_board_top" severity note;
    clock_enable <= false;
    wait;
  end process;

  watchdog : process
  begin
    wait for 100 us;
    assert false report "tb_board_top watchdog expired" severity failure;
  end process;
end architecture;
