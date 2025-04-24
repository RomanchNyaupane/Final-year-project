library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Tx_FIFO is
    port(
        data_in : in std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(7 downto 0);
        address : in integer range 0 to 2047;
        address_valid : in std_logic;
        data_ready : in std_logic;          --receiver ready
        data_ready_ack : out std_logic;     --acknowledge data_ready
        read_en : in std_logic;
        write_en : in std_logic;
        reset : in std_logic;
        clk : in std_logic
    );
end Tx_FIFO;

architecture rtl of Tx_FIFO is
    type MAC_fifo_mem is array(0 to 2047) of std_logic_vector(7 downto 0);
    signal MAC_fifo : MAC_fifo_mem;
    signal data_out_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal address_holder : integer range 0 to 2047 := 0;

    -- Handshake signals
    signal data_ready_ack_reg : std_logic := '0';
begin

    data_ready_ack <= data_ready_ack_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                data_out_reg <= (others => '0');
                address_holder <= 0;
                data_ready_ack_reg <= '0';
            else
                data_ready_ack_reg <= '0';
                if address_valid = '1' then
                    address_holder <= address;
                end if;
                if data_ready = '1' then
                    data_ready_ack_reg <= '1';
                end if;
                if write_en = '1' and data_ready = '1' then
                    data_ready_ack_reg <= '0';
                    MAC_fifo(address_holder) <= data_in;
                end if;
                if read_en = '1' then
                    data_out_reg <= MAC_fifo(address_holder);
                end if;
            end if;
        end if;
    end process;

    data_out <= data_out_reg;

end rtl;
