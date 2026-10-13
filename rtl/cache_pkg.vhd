library ieee;
use ieee.std_logic_1164.all;

package cache_pkg is
  constant LINE_COUNT : natural := 8;
  constant LINE_BYTES : natural := 32;

  subtype tag_t is std_logic_vector(7 downto 0);
  subtype index_t is std_logic_vector(2 downto 0);
  subtype offset_t is std_logic_vector(4 downto 0);
  subtype byte_t is std_logic_vector(7 downto 0);
  subtype address_t is std_logic_vector(15 downto 0);

  type cache_state_t is (IDLE, LOOKUP, READ_SETUP, READ_CAPTURE,
    WRITE_COMMIT, WB_RAM_SETUP, WB_RAM_CAPTURE, WB_MEM_SETUP,
    WB_MEM_STROBE, WB_NEXT, RF_MEM_SETUP, RF_MEM_STROBE,
    RF_RAM_WRITE, RF_NEXT);
  type tag_array_t is array (0 to LINE_COUNT-1) of tag_t;

  constant CASE_READ_HIT       : std_logic_vector(2 downto 0) := "000";
  constant CASE_WRITE_HIT      : std_logic_vector(2 downto 0) := "001";
  constant CASE_CLEAN_READ     : std_logic_vector(2 downto 0) := "010";
  constant CASE_CLEAN_WRITE    : std_logic_vector(2 downto 0) := "011";
  constant CASE_DIRTY_READ     : std_logic_vector(2 downto 0) := "100";
  constant CASE_DIRTY_WRITE    : std_logic_vector(2 downto 0) := "101";
end package;
