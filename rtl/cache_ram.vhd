library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_ram is
  port (
    clk   : in  std_logic;
    we    : in  std_logic;
    addr  : in  std_logic_vector(7 downto 0);
    wdata : in  std_logic_vector(7 downto 0);
    rdata : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of cache_ram is
  type ram_t is array (0 to 255) of std_logic_vector(7 downto 0);
  signal memory : ram_t;
  attribute ram_style : string;
  attribute ram_style of memory : signal is "block";
  signal data_out : std_logic_vector(7 downto 0);
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        memory(to_integer(unsigned(addr))) <= wdata;
        data_out <= wdata;
      else
        data_out <= memory(to_integer(unsigned(addr)));
      end if;
    end if;
  end process;
  rdata <= data_out;
end architecture;
