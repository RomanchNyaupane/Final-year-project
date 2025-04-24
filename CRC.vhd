library IEEE;
use IEEE.std_logic_1164.all;

entity CRC is
    port(
        clk         : in  std_logic;                        --system clock
        reset       : in  std_logic;                        --sync reset, active-high
        read_en     : in  std_logic;                        --shared read enable from TX controller
        data_in     : in  std_logic_vector(7 downto 0);     --byte from Tx_FIFO
        crc_append  : in  std_logic;                        --pulse to append CRC
        data_out    : out std_logic_vector(7 downto 0);     --goes on to PHY
        --crcOut      : out std_logic_vector(31 downto 0);    --exposes current CRC (optional)
        
        crc_append_complete: out std_logic;
        crc_append_ack : out std_logic
    );
end entity;

architecture rtl of CRC is

    --states
    type state_type is (PASS_THRU, INSERT_CRC);
    signal state        : state_type := PASS_THRU;
    signal crc_byte_cnt : integer range 0 to 3 := 0;

    signal crc_reg      : std_logic_vector(31 downto 0) := (others => '1');  -- init = 0xFFFFFFFF
    signal crc_next     : std_logic_vector(31 downto 0);

begin

    ----------------------------------------------------------------
    --(standard CRC-32 polynomial)
    crc_next(0)  <= crc_reg(2)  xor crc_reg(8)  xor data_in(2);
    crc_next(1)  <= crc_reg(0)  xor crc_reg(3)  xor crc_reg(9)  xor data_in(0) xor data_in(3);
    crc_next(2)  <= crc_reg(0)  xor crc_reg(1)  xor crc_reg(4)  xor crc_reg(10) xor data_in(0) xor data_in(1) xor data_in(4);
    crc_next(3)  <= crc_reg(1)  xor crc_reg(2)  xor crc_reg(5)  xor crc_reg(11) xor data_in(1) xor data_in(2) xor data_in(5);
    crc_next(4)  <= crc_reg(0)  xor crc_reg(2)  xor crc_reg(3)  xor crc_reg(6)  xor crc_reg(12) xor data_in(0) xor data_in(2) xor data_in(3) xor data_in(6);
    crc_next(5)  <= crc_reg(1)  xor crc_reg(3)  xor crc_reg(4)  xor crc_reg(7)  xor crc_reg(13) xor data_in(1) xor data_in(3) xor data_in(4) xor data_in(7);
    crc_next(6)  <= crc_reg(4)  xor crc_reg(5)  xor crc_reg(14) xor data_in(4) xor data_in(5);
    crc_next(7)  <= crc_reg(0)  xor crc_reg(5)  xor crc_reg(6)  xor crc_reg(15) xor data_in(0) xor data_in(5) xor data_in(6);
    crc_next(8)  <= crc_reg(1)  xor crc_reg(6)  xor crc_reg(7)  xor crc_reg(16) xor data_in(1) xor data_in(6) xor data_in(7);
    crc_next(9)  <= crc_reg(7)  xor crc_reg(17) xor data_in(7);
    crc_next(10) <= crc_reg(2)  xor crc_reg(18) xor data_in(2);
    crc_next(11) <= crc_reg(3)  xor crc_reg(19) xor data_in(3);
    crc_next(12) <= crc_reg(0)  xor crc_reg(4)  xor crc_reg(20) xor data_in(0) xor data_in(4);
    crc_next(13) <= crc_reg(0)  xor crc_reg(1)  xor crc_reg(5)  xor crc_reg(21) xor data_in(0) xor data_in(1) xor data_in(5);
    crc_next(14) <= crc_reg(1)  xor crc_reg(2)  xor crc_reg(6)  xor crc_reg(22) xor data_in(1) xor data_in(2) xor data_in(6);
    crc_next(15) <= crc_reg(2)  xor crc_reg(3)  xor crc_reg(7)  xor crc_reg(23) xor data_in(2) xor data_in(3) xor data_in(7);
    crc_next(16) <= crc_reg(0)  xor crc_reg(2)  xor crc_reg(3)  xor crc_reg(4)  xor crc_reg(24) xor data_in(0) xor data_in(2) xor data_in(3) xor data_in(4);
    crc_next(17) <= crc_reg(0)  xor crc_reg(1)  xor crc_reg(3)  xor crc_reg(4)  xor crc_reg(5)  xor crc_reg(25) xor data_in(0) xor data_in(1) xor data_in(3) xor data_in(4) xor data_in(5);
    crc_next(18) <= crc_reg(0)  xor crc_reg(1)  xor crc_reg(2)  xor crc_reg(4)  xor crc_reg(5)  xor crc_reg(6)  xor crc_reg(26) xor data_in(0) xor data_in(1) xor data_in(2) xor data_in(4) xor data_in(5) xor data_in(6);
    crc_next(19) <= crc_reg(1)  xor crc_reg(2)  xor crc_reg(3)  xor crc_reg(5)  xor crc_reg(6)  xor crc_reg(7)  xor crc_reg(27) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(5) xor data_in(6) xor data_in(7);
    crc_next(20) <= crc_reg(3)  xor crc_reg(4)  xor crc_reg(6)  xor crc_reg(7)  xor crc_reg(28) xor data_in(3) xor data_in(4) xor data_in(6) xor data_in(7);
    crc_next(21) <= crc_reg(2)  xor crc_reg(4)  xor crc_reg(5)  xor crc_reg(7)  xor crc_reg(29) xor data_in(2) xor data_in(4) xor data_in(5) xor data_in(7);
    crc_next(22) <= crc_reg(2)  xor crc_reg(3)  xor crc_reg(5)  xor crc_reg(6)  xor crc_reg(30) xor data_in(2) xor data_in(3) xor data_in(5) xor data_in(6);
    crc_next(23) <= crc_reg(3)  xor crc_reg(4)  xor crc_reg(6)  xor crc_reg(7)  xor crc_reg(31) xor data_in(3) xor data_in(4) xor data_in(6) xor data_in(7);
    crc_next(24) <= crc_reg(0)  xor crc_reg(2)  xor crc_reg(4)  xor crc_reg(5)  xor crc_reg(7)  xor data_in(0) xor data_in(2) xor data_in(4) xor data_in(5) xor data_in(7);
    crc_next(25) <= crc_reg(0)  xor crc_reg(1)  xor crc_reg(2)  xor crc_reg(3)  xor crc_reg(5)  xor crc_reg(6)  xor data_in(0) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(5) xor data_in(6);
    crc_next(26) <= crc_reg(0)  xor crc_reg(1)  xor crc_reg(2)  xor crc_reg(3)  xor crc_reg(4)  xor crc_reg(6)  xor crc_reg(7)  xor data_in(0) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(4) xor data_in(6) xor data_in(7);
    crc_next(27) <= crc_reg(1)  xor crc_reg(3)  xor crc_reg(4)  xor crc_reg(5)  xor crc_reg(7)  xor data_in(1) xor data_in(3) xor data_in(4) xor data_in(5) xor data_in(7);
    crc_next(28) <= crc_reg(0)  xor crc_reg(4)  xor crc_reg(5)  xor crc_reg(6)  xor data_in(0) xor data_in(4) xor data_in(5) xor data_in(6);
    crc_next(29) <= crc_reg(0)  xor crc_reg(1)  xor crc_reg(5)  xor crc_reg(6)  xor crc_reg(7)  xor data_in(0) xor data_in(1) xor data_in(5) xor data_in(6) xor data_in(7);
    crc_next(30) <= crc_reg(0)  xor crc_reg(1)  xor crc_reg(6)  xor crc_reg(7)  xor data_in(0) xor data_in(1) xor data_in(6) xor data_in(7);
    crc_next(31) <= crc_reg(1)  xor crc_reg(7)  xor data_in(1)  xor data_in(7);


    process(clk, reset)
    begin
        if reset = '1' then
            state        <= PASS_THRU;
            crc_reg      <= (others => '1');
            crc_byte_cnt <= 0;
            data_out     <= (others => '0');

        elsif rising_edge(clk) then
            crc_append_complete <= '0';

            case state is
              ----------------------------------------------------------
              when PASS_THRU =>
                if read_en = '1' then
                    -- forward FIFO byte & update CRC
                    data_out <= data_in;
                    crc_reg  <= crc_next;
                end if;

                --on crc_append pulse,switch to injecting CRC
                if crc_append = '1' then
                    state        <= INSERT_CRC;
                    crc_byte_cnt <= 0;
                end if;

              ----------------------------------------------------------
              when INSERT_CRC =>
                -- inject one CRC byte per cycle (MSB first)
                case crc_byte_cnt is
                    when 0 => data_out <= crc_reg(31 downto 24);
                    when 1 => data_out <= crc_reg(23 downto 16);
                    when 2 => data_out <= crc_reg(15 downto  8);
                    when 3 => 
                        data_out <= crc_reg( 7 downto  0);
                        crc_append_complete <= '1';
                    when others => null;
                end case;

                -- after the 4th byte, reset and go back
                if crc_byte_cnt = 3 then
                    state   <= PASS_THRU;
                    crc_reg <= (others => '1');  -- re-init for next frame
                end if;
                crc_byte_cnt <= crc_byte_cnt + 1;

            end case;
        end if;
    end process;

    ----------------------------------------------------------------
    --crcOut <= crc_reg;

end rtl;
