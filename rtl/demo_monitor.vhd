library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity demo_monitor is
  generic (
    EXTENDED : boolean := false
  );
  port (
    clk                   : in  std_logic;
    rst                   : in  std_logic;
    init_done             : in  std_logic;
    memory_unsupported    : in  std_logic;
    cpu_rdy               : in  std_logic;
    cpu_rdata             : in  std_logic_vector(7 downto 0);
    cpu_wr                : in  std_logic;
    cpu_step              : in  std_logic_vector(3 downto 0);
    cpu_finished          : in  std_logic;
    mem_addr              : in  std_logic_vector(15 downto 0);
    mem_wr                : in  std_logic;
    mem_strb              : in  std_logic;
    mem_wdata             : in  std_logic_vector(7 downto 0);
    dbg_accept            : in  std_logic;
    dbg_lookup            : in  std_logic;
    dbg_done              : in  std_logic;
    dbg_replacement_done  : in  std_logic;
    dbg_ram_setup         : in  std_logic;
    dbg_ram_capture       : in  std_logic;
    dbg_case              : in  std_logic_vector(2 downto 0);
    demo_pass             : out std_logic;
    demo_fault            : out std_logic;
    completed_count       : out std_logic_vector(7 downto 0);
    memory_read_count     : out std_logic_vector(15 downto 0);
    memory_write_count    : out std_logic_vector(15 downto 0);
    last_latency          : out std_logic_vector(15 downto 0);
    max_latency           : out std_logic_vector(15 downto 0);
    lookup_cycles         : out std_logic_vector(15 downto 0);
    ram_access_cycles     : out std_logic_vector(15 downto 0);
    replacement_cycles    : out std_logic_vector(15 downto 0);
    read_hit_cycles       : out std_logic_vector(15 downto 0);
    write_hit_cycles      : out std_logic_vector(15 downto 0);
    clean_miss_penalty    : out std_logic_vector(15 downto 0);
    dirty_miss_penalty    : out std_logic_vector(15 downto 0);
    saw_offset_31         : out std_logic
  );
end entity;

architecture rtl of demo_monitor is
  function expected_transactions return integer is
  begin
    if EXTENDED then return 16; else return 8; end if;
  end function;
  function expected_reads return integer is
  begin
    if EXTENDED then return 352; else return 160; end if;
  end function;
  function expected_writes return integer is
  begin
    if EXTENDED then return 96; else return 64; end if;
  end function;
  signal fault : std_logic := '0';
  signal complete_total : integer range 0 to 255 := 0;
  signal read_total : integer range 0 to 65535 := 0;
  signal write_total : integer range 0 to 65535 := 0;
  signal latency : integer range 0 to 65535 := 0;
  signal last_cycles : integer range 0 to 65535 := 0;
  signal max_cycles : integer range 0 to 65535 := 0;
  signal request_cycles : integer range 0 to 65535 := 0;
  signal lookup_measure : integer range 0 to 65535 := 0;
  signal ram_measure : integer range 0 to 65535 := 0;
  signal replacement_measure : integer range 0 to 65535 := 0;
  signal replacement_age : integer range 0 to 65535 := 0;
  signal ram_age : integer range 0 to 65535 := 0;
  signal read_hit_measure : integer range 0 to 65535 := 0;
  signal write_hit_measure : integer range 0 to 65535 := 0;
  signal clean_penalty_measure : integer range 0 to 65535 := 0;
  signal dirty_penalty_measure : integer range 0 to 65535 := 0;
  signal replacement_active : std_logic := '0';
  signal ram_active : std_logic := '0';
  signal request_case : std_logic_vector(2 downto 0) := "000";
  signal busy_seen : std_logic := '0';
  signal rdy_previous : std_logic := '1';
  signal strb_previous : std_logic := '0';
  signal addr_previous : std_logic_vector(15 downto 0) := (others => '0');
  signal wr_previous : std_logic := '0';
  signal wdata_previous : std_logic_vector(7 downto 0) := (others => '0');
  signal offset31 : std_logic := '0';
begin
  demo_fault <= fault;
  completed_count <= std_logic_vector(to_unsigned(complete_total, 8));
  memory_read_count <= std_logic_vector(to_unsigned(read_total, 16));
  memory_write_count <= std_logic_vector(to_unsigned(write_total, 16));
  last_latency <= std_logic_vector(to_unsigned(last_cycles, 16));
  max_latency <= std_logic_vector(to_unsigned(max_cycles, 16));
  lookup_cycles <= std_logic_vector(to_unsigned(lookup_measure, 16));
  ram_access_cycles <= std_logic_vector(to_unsigned(ram_measure, 16));
  replacement_cycles <= std_logic_vector(to_unsigned(replacement_measure, 16));
  read_hit_cycles <= std_logic_vector(to_unsigned(read_hit_measure, 16));
  write_hit_cycles <= std_logic_vector(to_unsigned(write_hit_measure, 16));
  clean_miss_penalty <= std_logic_vector(to_unsigned(clean_penalty_measure, 16));
  dirty_miss_penalty <= std_logic_vector(to_unsigned(dirty_penalty_measure, 16));
  saw_offset_31 <= offset31;
  demo_pass <= '1' when cpu_finished = '1' and fault = '0' and
      init_done = '1' and complete_total = expected_transactions and
      read_total = expected_reads and write_total = expected_writes and
      offset31 = '1' else '0';

  process (clk)
    variable expected : std_logic_vector(7 downto 0);
    variable check_read : boolean;
    variable next_latency : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        fault <= '0';
        complete_total <= 0;
        read_total <= 0;
        write_total <= 0;
        latency <= 0;
        last_cycles <= 0;
        max_cycles <= 0;
        request_cycles <= 0;
        lookup_measure <= 0;
        ram_measure <= 0;
        replacement_measure <= 0;
        replacement_age <= 0;
        ram_age <= 0;
        read_hit_measure <= 0;
        write_hit_measure <= 0;
        clean_penalty_measure <= 0;
        dirty_penalty_measure <= 0;
        replacement_active <= '0';
        ram_active <= '0';
        request_case <= "000";
        busy_seen <= '0';
        rdy_previous <= '1';
        strb_previous <= '0';
        addr_previous <= (others => '0');
        wr_previous <= '0';
        wdata_previous <= (others => '0');
        offset31 <= '0';
      else
        if dbg_accept = '1' then
          request_cycles <= 0;
        elsif cpu_rdy = '0' then
          if request_cycles < 65535 then
            request_cycles <= request_cycles + 1;
          else
            fault <= '1';
          end if;
        end if;
        if dbg_lookup = '1' then
          if request_cycles < 65535 then
            lookup_measure <= request_cycles + 1;
          else
            lookup_measure <= 65535;
            fault <= '1';
          end if;
          request_case <= dbg_case;
          replacement_age <= 0;
          if dbg_case = "010" or dbg_case = "011" or
             dbg_case = "100" or dbg_case = "101" then
            replacement_active <= '1';
          else
            replacement_active <= '0';
          end if;
        elsif replacement_active = '1' then
          if replacement_age < 65535 then
            replacement_age <= replacement_age + 1;
          else
            fault <= '1';
          end if;
        end if;
        if dbg_replacement_done = '1' then
          if replacement_age < 65535 then
            replacement_measure <= replacement_age + 1;
          else
            replacement_measure <= 65535;
            fault <= '1';
          end if;
          replacement_active <= '0';
        end if;
        if dbg_ram_setup = '1' then
          if ram_active = '1' then
            fault <= '1';
          end if;
          ram_active <= '1';
          ram_age <= 0;
        elsif dbg_ram_capture = '1' and ram_active = '1' then
          if ram_age < 65535 then
            ram_measure <= ram_age + 1;
          else
            ram_measure <= 65535;
            fault <= '1';
          end if;
          ram_active <= '0';
        elsif dbg_ram_capture = '1' then
          fault <= '1';
        elsif ram_active = '1' then
          if ram_age < 65535 then
            ram_age <= ram_age + 1;
          else
            fault <= '1';
          end if;
        end if;
        if memory_unsupported = '1' then
          fault <= '1';
        end if;
        if dbg_accept = '1' and init_done /= '1' then
          fault <= '1';
        end if;
        if dbg_done = '1' and dbg_accept = '1' then
          fault <= '1';
        end if;
        if dbg_replacement_done = '1' and dbg_done /= '0' then
          fault <= '1';
        end if;

        if mem_strb = '1' then
          if strb_previous = '1' or mem_addr /= addr_previous or
             mem_wr /= wr_previous or
             (mem_wr = '1' and mem_wdata /= wdata_previous) then
            fault <= '1';
          end if;
          if mem_addr(4 downto 0) = "11111" then
            offset31 <= '1';
          end if;
          if mem_wr = '1' then
            if write_total < 65535 then
              write_total <= write_total + 1;
            else
              fault <= '1';
            end if;
          elsif mem_wr = '0' then
            if read_total < 65535 then
              read_total <= read_total + 1;
            else
              fault <= '1';
            end if;
          else
            fault <= '1';
          end if;
        elsif mem_strb /= '0' then
          fault <= '1';
        end if;
        strb_previous <= mem_strb;
        addr_previous <= mem_addr;
        wr_previous <= mem_wr;
        wdata_previous <= mem_wdata;

        if cpu_rdy = '0' then
          busy_seen <= '1';
          if latency < 65535 then
            latency <= latency + 1;
          else
            fault <= '1';
          end if;
        elsif busy_seen = '1' and rdy_previous = '0' then
          if complete_total < 255 then
            complete_total <= complete_total + 1;
          else
            fault <= '1';
          end if;
          next_latency := latency;
          last_cycles <= next_latency;
          if next_latency > max_cycles then
            max_cycles <= next_latency;
          end if;
          latency <= 0;
          busy_seen <= '0';
          expected := x"FF";
          check_read := false;
          case cpu_step is
            when "0010" => expected := x"AA"; check_read := true;
            when "0011" => expected := x"BB"; check_read := true;
            when "0100" => expected := x"FF"; check_read := true;
            when "0101" => expected := x"FF"; check_read := true;
            when "0111" => expected := x"FF"; check_read := true;
            when "1000" => expected := x"AA"; check_read := true;
            when "1001" => expected := x"BB"; check_read := true;
            when "1010" => expected := x"CC"; check_read := true;
            when "1011" => expected := x"FF"; check_read := true;
            when "1101" => expected := x"AA"; check_read := true;
            when "1110" => expected := x"D7"; check_read := true;
            when "1111" => expected := x"FF"; check_read := true;
            when others => null;
          end case;
          if check_read then
            if cpu_wr /= '0' or cpu_rdata /= expected then
              fault <= '1';
            end if;
          elsif cpu_wr /= '1' then
            fault <= '1';
          end if;
          case request_case is
            when "000" => read_hit_measure <= next_latency;
            when "001" => write_hit_measure <= next_latency;
            when "010" | "011" =>
              if cpu_wr = '0' and next_latency > 3 then
                clean_penalty_measure <= next_latency - 3;
              elsif cpu_wr = '1' and next_latency > 2 then
                clean_penalty_measure <= next_latency - 2;
              end if;
            when "100" | "101" =>
              if cpu_wr = '0' and next_latency > 3 then
                dirty_penalty_measure <= next_latency - 3;
              elsif cpu_wr = '1' and next_latency > 2 then
                dirty_penalty_measure <= next_latency - 2;
              end if;
            when others => null;
          end case;
        end if;
        rdy_previous <= cpu_rdy;
      end if;
    end if;
  end process;
end architecture;
