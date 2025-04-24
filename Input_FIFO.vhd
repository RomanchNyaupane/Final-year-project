library IEEE;
use IEEE.std_logic_1164.all;

entity Input_FIFO is
    port(
    --data and address ports
    IF_data_in : in std_logic_vector(7 downto 0);
    IF_data_out : out std_logic_vector(7 downto 0);
    IF_address : in integer range 0 to 2047;
    IF_address_valid : in std_logic;
    
    IF_data_ready : in std_logic; --input fifo data ready check
    IF_data_ready_ack : out std_logic; --input fifo data ready acknowledgment
    
    --control ports
    IF_read_en : in std_logic; --enable before reading data
    IF_write_en : in std_logic; --enable before writing data
    IF_reset : in std_logic;
    IF_clk : in std_logic
    );
end Input_FIFO;


architecture rtl of Input_FIFO is
type INPUT_fifo_mem is array(0 to 2047) of std_logic_vector(7 downto 0);
signal Input_fifo : Input_fifo_mem;
signal data_out_reg : std_logic_vector(7 downto 0) := "00000000";
signal address_holder : integer range 0 to 2047;

begin
process(IF_clk) begin
if rising_edge(IF_clk) then
    
    if IF_address_valid = '1' then
        address_holder <= IF_address;
    end if;
    if IF_data_ready = '1' then
        IF_data_ready_ack <= '1';
    else
        IF_data_ready_ack <= '0';
    end if;
    
    if IF_reset = '1' then
        data_out_reg <= "00000000";
    else
        if IF_read_en = '1' and IF_write_en = '0' then
            data_out_reg <= Input_fifo(address_holder);
        end if;
        if IF_write_en = '1' and IF_read_en = '0' then
            Input_fifo(address_holder) <= IF_data_in;
        end if;
    end if;
end if;
end process;
IF_data_out<=data_out_reg;
end rtl;