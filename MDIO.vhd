library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MDIO is
    Port (
        clk_50mhz       : in  STD_LOGIC;
        reset_n         : in  STD_LOGIC;
        mdc             : out STD_LOGIC;
        mdio            : inout STD_LOGIC;
        phy_setup_start : in  STD_LOGIC;
        phy_ready       : out STD_LOGIC;
        config_error    : out STD_LOGIC
    );
end MDIO;

architecture rtl of MDIO is
    constant PREAMBLE   : std_logic_vector(31 downto 0) := x"FFFFFFFF";
    constant START      : std_logic_vector(1 downto 0) := "01";
    constant OP_WRITE   : std_logic_vector(1 downto 0) := "01";
    constant PHY_ADDR   : std_logic_vector(4 downto 0) := "00000";
    constant TA_WRITE   : std_logic_vector(1 downto 0) := "10";
    
    --register addresses
    constant BMCR_ADDR  : std_logic_vector(4 downto 0) := "00000";
    constant GBCR_ADDR  : std_logic_vector(4 downto 0) := "01001";
    constant ANAR_ADDR  : std_logic_vector(4 downto 0) := "00100";
    
    --configuration values
    constant BMCR_VAL   : std_logic_vector(15 downto 0) := x"0100";
    constant GBCR_VAL   : std_logic_vector(15 downto 0) := x"0000";
    constant ANAR_VAL   : std_logic_vector(15 downto 0) := x"0000";

    signal mdc_reg      : std_logic := '0';
    signal mdc_counter : integer range 0 to 19 := 0;
    
    signal mdio_out     : std_logic := '1';
    signal mdio_dir     : std_logic := '0';
    signal shift_reg    : std_logic_vector(63 downto 0) := (others => '0');
    signal bit_counter  : integer range 0 to 63 := 0;
    
    type state_type is (IDLE, PREPARE_FRAME, SEND_FRAME, DONE);
    signal state        : state_type := IDLE;
    signal setup_count  : integer range 0 to 3 := 0;
    signal start_send   : std_logic := '0';
    signal frame_sent   : std_logic := '0';

begin
    --MDC Clock 
    process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if mdc_counter = 19 then
                mdc_counter <= 0;
                mdc_reg <= not mdc_reg;
            else
                mdc_counter <= mdc_counter + 1;
            end if;
        end if;
    end process;

    mdc <= mdc_reg;
    mdio <= mdio_out when mdio_dir = '1' else 'Z';

    process(clk_50mhz, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            setup_count <= 0;
            phy_ready <= '0';
            config_error <= '0';
            start_send <= '0';
            mdio_dir <= '0';
            mdio_out <= '1';
            bit_counter <= 0;
            shift_reg <= (others => '0');
        elsif rising_edge(clk_50mhz) then
            frame_sent <= '0';
            
            case state is
                when IDLE =>
                    if phy_setup_start = '1' then
                        state <= PREPARE_FRAME;
                        setup_count <= 0;
                    end if;
                
                when PREPARE_FRAME =>
                    -- prepare the appropriate frame based on setup_count
                    case setup_count is
                        when 0 => shift_reg <= PREAMBLE & START & OP_WRITE & PHY_ADDR & BMCR_ADDR & TA_WRITE & BMCR_VAL;
                        when 1 => shift_reg <= PREAMBLE & START & OP_WRITE & PHY_ADDR & GBCR_ADDR & TA_WRITE & GBCR_VAL;
                        when 2 => shift_reg <= PREAMBLE & START & OP_WRITE & PHY_ADDR & ANAR_ADDR & TA_WRITE & ANAR_VAL;
                        when others => null;
                    end case;
                    bit_counter <= 0;
                    state <= SEND_FRAME;
                    start_send <= '1';
                    mdio_dir <= '1';
                
        when SEND_FRAME =>
            --bit transmission on MDC falling edge
            if mdc_counter = 10 then  --falling edge approximation
                mdio_out <= shift_reg(63 - bit_counter);
                
                if bit_counter = 63 then
                    frame_sent <= '1';
                    mdio_dir <= '0';
                    if setup_count = 2 then
                        state <= DONE;
                    else
                        setup_count <= setup_count + 1;
                        state <= PREPARE_FRAME;
                    end if;
                else
                    bit_counter <= bit_counter + 1;
                end if;
            end if;
                
                when DONE =>
                    phy_ready <= '1';
                    if phy_setup_start = '0' then
                        state <= IDLE;
                        phy_ready <= '0';
                    end if;
            end case;
        end if;
    end process;

end rtl;