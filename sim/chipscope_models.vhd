-- Simulation stand-ins for generated vendor cores. Never add this file to XST.
library ieee;
use ieee.std_logic_1164.all;

package chipscope_tb_pkg is
  signal vio_outputs : std_logic_vector(1 downto 0) := "01";
  signal vio_inputs : std_logic_vector(191 downto 0);
  signal ila_inputs : std_logic_vector(127 downto 0);
end package;

library ieee;
use ieee.std_logic_1164.all;
entity cache_icon is
  port (CONTROL0, CONTROL1 : inout std_logic_vector(35 downto 0));
end entity;
architecture simulation of cache_icon is
begin
  CONTROL0 <= (others => 'Z');
  CONTROL1 <= (others => 'Z');
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use work.chipscope_tb_pkg.all;
entity cache_vio is
  port (CONTROL : inout std_logic_vector(35 downto 0);
        CLK : in std_logic;
        SYNC_IN : in std_logic_vector(191 downto 0);
        SYNC_OUT : out std_logic_vector(1 downto 0));
end entity;
architecture simulation of cache_vio is
begin
  SYNC_OUT <= vio_outputs;
  vio_inputs <= SYNC_IN;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use work.chipscope_tb_pkg.all;
entity cache_ila is
  port (CONTROL : inout std_logic_vector(35 downto 0);
        CLK : in std_logic;
        TRIG0 : in std_logic_vector(127 downto 0));
end entity;
architecture simulation of cache_ila is
begin
  ila_inputs <= TRIG0;
end architecture;
