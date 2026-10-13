library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cache_pkg.all;

entity cache_controller is
  port (
    clk, rst : in std_logic;
    cpu_cs, cpu_wr : in std_logic;
    cpu_addr : in std_logic_vector(15 downto 0);
    cpu_wdata : in std_logic_vector(7 downto 0);
    cpu_rdy : out std_logic;
    cpu_rdata : out std_logic_vector(7 downto 0);
    ram_addr : out std_logic_vector(7 downto 0);
    ram_we : out std_logic;
    ram_wdata : out std_logic_vector(7 downto 0);
    ram_rdata : in std_logic_vector(7 downto 0);
    mem_addr : out std_logic_vector(15 downto 0);
    mem_wr, mem_strb : out std_logic;
    mem_wdata : out std_logic_vector(7 downto 0);
    mem_rdata : in std_logic_vector(7 downto 0);
    dbg_accept, dbg_lookup, dbg_done, dbg_replacement_done : out std_logic;
    dbg_ram_setup, dbg_ram_capture : out std_logic;
    dbg_case : out std_logic_vector(2 downto 0);
    dbg_state : out std_logic_vector(3 downto 0);
    dbg_byte : out std_logic_vector(4 downto 0);
    dbg_valid, dbg_dirty : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of cache_controller is
  signal state : cache_state_t := IDLE;
  signal cs_previous : std_logic := '0';
  signal request_addr : std_logic_vector(15 downto 0) := (others => '0');
  signal request_wr : std_logic := '0';
  signal request_data : std_logic_vector(7 downto 0) := (others => '0');
  signal victim_base : std_logic_vector(15 downto 0) := (others => '0');
  signal byte_count : unsigned(4 downto 0) := (others => '0');
  signal byte_buffer : std_logic_vector(7 downto 0) := (others => '0');
  signal tags : tag_array_t := (others => (others => '0'));
  signal valid_bits, dirty_bits : std_logic_vector(7 downto 0) := (others => '0');
  signal response : std_logic_vector(7 downto 0) := (others => '0');
  signal case_code : std_logic_vector(2 downto 0) := "000";
begin
  cpu_rdata <= response;
  dbg_case <= case_code;
  dbg_byte <= std_logic_vector(byte_count);
  dbg_valid <= valid_bits;
  dbg_dirty <= dirty_bits;
  dbg_state <= std_logic_vector(to_unsigned(cache_state_t'pos(state), 4));
  cpu_rdy <= '1' when state = IDLE and rst = '0' else '0';

  process (state, rst, request_addr, request_wr, request_data,
           victim_base, byte_count, byte_buffer)
    variable index_byte : std_logic_vector(7 downto 0);
    variable transfer_addr : unsigned(15 downto 0);
  begin
    ram_addr <= request_addr(7 downto 0);
    ram_we <= '0';
    ram_wdata <= request_data;
    mem_addr <= request_addr(15 downto 5) & std_logic_vector(byte_count);
    mem_wr <= '0';
    mem_strb <= '0';
    mem_wdata <= byte_buffer;
    dbg_ram_setup <= '0';
    dbg_ram_capture <= '0';

    index_byte := request_addr(7 downto 5) & std_logic_vector(byte_count);
    transfer_addr := shift_left(resize(unsigned(request_addr(15 downto 5)), 16), 5) + resize(byte_count, 16);
    case state is
      when READ_SETUP =>
        ram_addr <= request_addr(7 downto 0);
        dbg_ram_setup <= '1';
      when READ_CAPTURE =>
        ram_addr <= request_addr(7 downto 0);
        dbg_ram_capture <= '1';
      when WRITE_COMMIT =>
        ram_addr <= request_addr(7 downto 0);
        if rst = '0' then ram_we <= '1'; end if;
        ram_wdata <= request_data;
      when WB_RAM_SETUP =>
        ram_addr <= index_byte;
        dbg_ram_setup <= '1';
      when WB_RAM_CAPTURE =>
        ram_addr <= index_byte;
        dbg_ram_capture <= '1';
      when WB_MEM_SETUP =>
        mem_addr <= std_logic_vector(unsigned(victim_base) + resize(byte_count, 16));
        mem_wr <= '1';
        mem_wdata <= byte_buffer;
      when WB_MEM_STROBE =>
        mem_addr <= std_logic_vector(unsigned(victim_base) + resize(byte_count, 16));
        mem_wr <= '1';
        mem_wdata <= byte_buffer;
        if rst = '0' then mem_strb <= '1'; end if;
      when RF_MEM_SETUP =>
        mem_addr <= std_logic_vector(transfer_addr);
      when RF_MEM_STROBE =>
        mem_addr <= std_logic_vector(transfer_addr);
        if rst = '0' then mem_strb <= '1'; end if;
      when RF_RAM_WRITE =>
        ram_addr <= index_byte;
        if rst = '0' then ram_we <= '1'; end if;
        ram_wdata <= byte_buffer;
      when others => null;
    end case;
    if rst = '1' then
      ram_we <= '0';
      mem_strb <= '0';
      mem_wr <= '0';
    end if;
  end process;

  process (clk)
    variable idx : natural range 0 to 7;
  begin
    if rising_edge(clk) then
      dbg_accept <= '0';
      dbg_lookup <= '0';
      dbg_done <= '0';
      dbg_replacement_done <= '0';
      cs_previous <= cpu_cs;
      if rst = '1' then
        state <= IDLE;
        valid_bits <= (others => '0');
        dirty_bits <= (others => '0');
        tags <= (others => (others => '0'));
        request_addr <= (others => '0');
        request_wr <= '0';
        request_data <= (others => '0');
        victim_base <= (others => '0');
        byte_count <= (others => '0');
        byte_buffer <= (others => '0');
        response <= (others => '0');
        case_code <= "000";
      else
        case state is
          when IDLE =>
            if cpu_cs = '1' and cs_previous = '0' then
              request_addr <= cpu_addr;
              request_wr <= cpu_wr;
              request_data <= cpu_wdata;
              state <= LOOKUP;
              dbg_accept <= '1';
            end if;
          when LOOKUP =>
            idx := to_integer(unsigned(request_addr(7 downto 5)));
            dbg_lookup <= '1';
            if valid_bits(idx) = '1' and tags(idx) = request_addr(15 downto 8) then
              if request_wr = '1' then
                case_code <= CASE_WRITE_HIT;
                state <= WRITE_COMMIT;
              else
                case_code <= CASE_READ_HIT;
                state <= READ_SETUP;
              end if;
            else
              if valid_bits(idx) = '1' and dirty_bits(idx) = '1' then
                victim_base <= tags(idx) & request_addr(7 downto 5) & "00000";
                valid_bits(idx) <= '0';
                if request_wr = '1' then case_code <= CASE_DIRTY_WRITE;
                else case_code <= CASE_DIRTY_READ; end if;
                state <= WB_RAM_SETUP;
              else
                if request_wr = '1' then case_code <= CASE_CLEAN_WRITE;
                else case_code <= CASE_CLEAN_READ; end if;
                byte_count <= (others => '0');
                valid_bits(idx) <= '0';
                state <= RF_MEM_SETUP;
              end if;
            end if;
          when READ_SETUP =>
            state <= READ_CAPTURE;
          when READ_CAPTURE =>
            response <= ram_rdata;
            dbg_done <= '1';
            state <= IDLE;
          when WRITE_COMMIT =>
            idx := to_integer(unsigned(request_addr(7 downto 5)));
            valid_bits(idx) <= '1';
            dirty_bits(idx) <= '1';
            tags(idx) <= request_addr(15 downto 8);
            dbg_done <= '1';
            state <= IDLE;
          when WB_RAM_SETUP =>
            state <= WB_RAM_CAPTURE;
          when WB_RAM_CAPTURE =>
            byte_buffer <= ram_rdata;
            state <= WB_MEM_SETUP;
          when WB_MEM_SETUP =>
            state <= WB_MEM_STROBE;
          when WB_MEM_STROBE =>
            state <= WB_NEXT;
          when WB_NEXT =>
            if byte_count = 31 then
              idx := to_integer(unsigned(request_addr(7 downto 5)));
              dirty_bits(idx) <= '0';
              byte_count <= (others => '0');
              state <= RF_MEM_SETUP;
            else
              byte_count <= byte_count + 1;
              state <= WB_RAM_SETUP;
            end if;
          when RF_MEM_SETUP =>
            state <= RF_MEM_STROBE;
          when RF_MEM_STROBE =>
            byte_buffer <= mem_rdata;
            state <= RF_RAM_WRITE;
          when RF_RAM_WRITE =>
            state <= RF_NEXT;
          when RF_NEXT =>
            if byte_count = 31 then
              idx := to_integer(unsigned(request_addr(7 downto 5)));
              tags(idx) <= request_addr(15 downto 8);
              valid_bits(idx) <= '1';
              dirty_bits(idx) <= '0';
              byte_count <= (others => '0');
              dbg_replacement_done <= '1';
              if request_wr = '1' then state <= WRITE_COMMIT;
              else state <= READ_SETUP; end if;
            else
              byte_count <= byte_count + 1;
              state <= RF_MEM_SETUP;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
