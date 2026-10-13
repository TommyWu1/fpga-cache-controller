library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Compact original stimulus sequencer for the published course vectors and
-- optional recovery/address-extension vectors. No third-party CPU source is
-- included in this repository.
entity demo_cpu is
  generic (
    EXTENDED : boolean := false
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    trig      : in  std_logic;
    cpu_rdy   : in  std_logic;
    cpu_rdata : in  std_logic_vector(7 downto 0);
    cpu_cs    : out std_logic;
    cpu_wr    : out std_logic;
    cpu_addr  : out std_logic_vector(15 downto 0);
    cpu_wdata : out std_logic_vector(7 downto 0);
    step      : out std_logic_vector(3 downto 0);
    active    : out std_logic;
    finished  : out std_logic
  );
end entity;

architecture rtl of demo_cpu is
  type state_t is (WAIT_TRIGGER, SETUP, STROBE, WAIT_READY, COMPLETE_STATE);
  type address_array_t is array (0 to 15) of std_logic_vector(15 downto 0);
  type byte_array_t is array (0 to 15) of std_logic_vector(7 downto 0);
  type direction_array_t is array (0 to 15) of std_logic;
  constant ADDRESSES : address_array_t := (
    x"1100", x"1102", x"1100", x"1102", x"3346", x"4444",
    x"5504", x"6606", x"1100", x"1102", x"5504", x"9100",
    x"911F", x"1100", x"911F", x"22FF"
  );
  constant WRITES : direction_array_t := (
    '1', '1', '0', '0', '0', '0', '1', '0',
    '0', '0', '0', '0', '1', '0', '0', '0'
  );
  constant WRITE_DATA : byte_array_t := (
    x"AA", x"BB", x"00", x"00", x"00", x"00", x"CC", x"00",
    x"00", x"00", x"00", x"00", x"D7", x"00", x"00", x"00"
  );
  signal state : state_t := WAIT_TRIGGER;
  signal transaction : integer range 0 to 15 := 0;
  signal pulse_count : integer range 0 to 3 := 0;
begin
  cpu_cs <= '1' when state = STROBE else '0';
  cpu_wr <= WRITES(transaction);
  cpu_addr <= ADDRESSES(transaction);
  cpu_wdata <= WRITE_DATA(transaction);
  step <= std_logic_vector(to_unsigned(transaction, 4));
  active <= '1' when state = STROBE or state = WAIT_READY else '0';
  finished <= '1' when state = COMPLETE_STATE else '0';

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= WAIT_TRIGGER;
        transaction <= 0;
        pulse_count <= 0;
      else
        case state is
          when WAIT_TRIGGER =>
            if trig = '1' then
              transaction <= 0;
              pulse_count <= 0;
              state <= SETUP;
            end if;
          when SETUP =>
            pulse_count <= 0;
            state <= STROBE;
          when STROBE =>
            if pulse_count = 3 then
              state <= WAIT_READY;
            else
              pulse_count <= pulse_count + 1;
            end if;
          when WAIT_READY =>
            if cpu_rdy = '1' then
              if transaction = 7 and not EXTENDED then
                state <= COMPLETE_STATE;
              elsif transaction = 15 then
                state <= COMPLETE_STATE;
              else
                transaction <= transaction + 1;
                pulse_count <= 0;
                state <= SETUP;
              end if;
            end if;
          when COMPLETE_STATE =>
            if trig = '1' then
              transaction <= 0;
              pulse_count <= 0;
              state <= SETUP;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
