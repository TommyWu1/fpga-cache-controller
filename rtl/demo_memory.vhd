library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Small, synthesizable backing store for the documented demonstration blocks.
-- It is not a general 64 KiB memory or a physical SDRAM controller.
entity demo_memory is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    mem_addr     : in  std_logic_vector(15 downto 0);
    mem_wr       : in  std_logic;
    mem_strb     : in  std_logic;
    mem_wdata    : in  std_logic_vector(7 downto 0);
    mem_rdata    : out std_logic_vector(7 downto 0);
    init_done    : out std_logic;
    unsupported  : out std_logic
  );
end entity;

architecture rtl of demo_memory is
  type memory_t is array (0 to 255) of std_logic_vector(7 downto 0);
  signal memory : memory_t;
  signal init_index : integer range 0 to 255 := 0;
  signal initialized : std_logic := '0';
  signal bad_address : std_logic := '0';

  -- Full block addresses are compared; bit 15 and all tag bits are retained.
  function block_number(a : std_logic_vector(15 downto 0)) return integer is
  begin
    case a(15 downto 5) is
      when "00010001000" => return 0; -- 0x1100
      when "00110011010" => return 1; -- 0x3340
      when "01000100010" => return 2; -- 0x4440
      when "01010101000" => return 3; -- 0x5500
      when "01100110000" => return 4; -- 0x6600
      when "10010001000" => return 5; -- 0x9100
      when "00100010111" => return 6; -- 0x22E0
      when "01110111111" => return 7; -- 0x77E0
      when others       => return -1;
    end case;
  end function;

  function selected_byte(a : std_logic_vector(15 downto 0);
                         m : memory_t) return std_logic_vector is
    variable b : integer;
    variable i : integer;
  begin
    b := block_number(a);
    if b < 0 then
      return x"FF";
    end if;
    i := b * 32 + to_integer(unsigned(a(4 downto 0)));
    return m(i);
  end function;
begin
  init_done <= initialized;
  unsupported <= bad_address;
  mem_rdata <= selected_byte(mem_addr, memory);

  process (clk)
    variable b : integer;
    variable i : integer range 0 to 255;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        init_index <= 0;
        initialized <= '0';
        bad_address <= '0';
      elsif initialized = '0' then
        memory(init_index) <= x"FF";
        if init_index = 255 then
          initialized <= '1';
        else
          init_index <= init_index + 1;
        end if;
      elsif mem_strb = '1' then
        b := block_number(mem_addr);
        if b < 0 then
          bad_address <= '1';
        elsif mem_wr = '1' then
          i := b * 32 + to_integer(unsigned(mem_addr(4 downto 0)));
          memory(i) <= mem_wdata;
        end if;
      end if;
    end if;
  end process;
end architecture;
