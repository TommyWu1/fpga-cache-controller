library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main_memory_model is
  generic (
    INIT_FF : boolean := false;
    REGISTERED_READ : boolean := false
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    mem_addr     : in  std_logic_vector(15 downto 0);
    mem_wr       : in  std_logic;
    mem_strb     : in  std_logic;
    mem_wdata    : in  std_logic_vector(7 downto 0);
    mem_rdata    : out std_logic_vector(7 downto 0);
    protocol_err : out std_logic;
    read_count   : out natural;
    write_count  : out natural
  );
end entity;

architecture simulation of main_memory_model is
  type memory_t is array (0 to 65535) of std_logic_vector(7 downto 0);
  function initial_memory(ff_mode : boolean) return memory_t is
    variable m : memory_t;
    variable v : integer;
  begin
    for a in 0 to 65535 loop
      if ff_mode then v := 255;
      else v := (17 * (a mod 256) + 29 * (a / 256) + 16#5A#) mod 256;
      end if;
      m(a) := std_logic_vector(to_unsigned(v, 8));
    end loop;
    return m;
  end function;
  signal memory : memory_t := initial_memory(INIT_FF);
  signal err : std_logic := '0';
  signal reads : natural := 0;
  signal writes : natural := 0;
  signal prev_strb : std_logic := '0';
  signal prev_addr : std_logic_vector(15 downto 0) := (others => '0');
  signal prev_wr : std_logic := '0';
  signal prev_wdata : std_logic_vector(7 downto 0) := (others => '0');
  signal registered_data : std_logic_vector(7 downto 0) := (others => '0');
begin
  protocol_err <= err;
  read_count <= reads;
  write_count <= writes;

  asynchronous_read : if not REGISTERED_READ generate
    process (mem_addr, memory)
      variable known : boolean;
    begin
      known := true;
      for bit_index in mem_addr'range loop
        if mem_addr(bit_index) /= '0' and mem_addr(bit_index) /= '1' then
          known := false;
        end if;
      end loop;
      if known then
        mem_rdata <= memory(to_integer(unsigned(mem_addr)));
      else
        mem_rdata <= (others => '0');
      end if;
    end process;
  end generate;

  registered_output : if REGISTERED_READ generate
    process (clk)
      variable known : boolean;
    begin
      if rising_edge(clk) then
        known := true;
        for bit_index in mem_addr'range loop
          if mem_addr(bit_index) /= '0' and mem_addr(bit_index) /= '1' then
            known := false;
          end if;
        end loop;
        if known then
          registered_data <= memory(to_integer(unsigned(mem_addr)));
        else
          registered_data <= (others => '0');
        end if;
      end if;
    end process;
    mem_rdata <= registered_data;
  end generate;

  process(clk)
    variable a : integer range 0 to 65535;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        err <= '0';
        reads <= 0;
        writes <= 0;
        prev_strb <= '0';
      else
        if mem_strb = '1' then
          a := to_integer(unsigned(mem_addr));
          if prev_strb = '1' or mem_addr /= prev_addr or mem_wr /= prev_wr or
             (mem_wr = '1' and mem_wdata /= prev_wdata) then
            err <= '1';
            assert false report "memory strobe not a one-cycle stable setup/pulse" severity error;
          end if;
          if mem_wr = '1' then
            memory(a) <= mem_wdata;
            writes <= writes + 1;
          elsif mem_wr = '0' then
            reads <= reads + 1;
          else
            err <= '1';
            assert false report "unknown memory direction" severity error;
          end if;
        elsif mem_strb /= '0' then
          err <= '1';
          assert false report "unknown memory strobe" severity error;
        end if;
        prev_strb <= mem_strb;
        prev_addr <= mem_addr;
        prev_wr <= mem_wr;
        prev_wdata <= mem_wdata;
      end if;
    end if;
  end process;
end architecture;
