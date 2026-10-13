library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package cache_tb_pkg is
  function pattern_byte(address : natural) return std_logic_vector;
  function line_address(tag_value, index_value : natural) return natural;
  function request_address(tag_value, index_value, offset_value : natural) return natural;
end package;

package body cache_tb_pkg is
  function pattern_byte(address : natural) return std_logic_vector is
    variable n : natural;
  begin
    n := (17 * (address mod 256) + 29 * (address / 256) + 16#5A#) mod 256;
    return std_logic_vector(to_unsigned(n, 8));
  end function;

  function line_address(tag_value, index_value : natural) return natural is
  begin
    return ((tag_value mod 256) * 256) + ((index_value mod 8) * 32);
  end function;

  function request_address(tag_value, index_value, offset_value : natural) return natural is
  begin
    return line_address(tag_value, index_value) + (offset_value mod 32);
  end function;
end package body;
