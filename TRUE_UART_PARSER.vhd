library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_parser is
    Port (
        CLK           : in  std_logic;
        RESET         : in  std_logic;
        DATA_IN       : in  std_logic_vector(7 downto 0);
        RX_VALID      : in  std_logic;
        
        tx_data       : out std_logic_vector(7 downto 0);
        tx_data_valid : out std_logic
    );
end UART_parser;

architecture Behavioral of UART_parser is

    type PARSER_STATE_TYPE is (IDLE, PARSING, DISPATCH, ERROR_STATE);
    signal STATE, NEXT_STATE : PARSER_STATE_TYPE := IDLE;

    -- Reduced buffer size to 16 bytes
    constant BUFFER_SIZE : integer := 16;
    
    type BYTE_ARRAY is array (0 to BUFFER_SIZE-1) of std_logic_vector(7 downto 0);
    signal CMD_BUFFER     : BYTE_ARRAY := (others => (others => '0'));
    
    signal COMMAND_BYTE   : std_logic_vector(7 downto 0) := (others => '0');
    signal COMMAND_TYPE   : std_logic_vector(3 downto 0) := (others => '0');
    signal BYTES_EXPECTED : integer range 0 to BUFFER_SIZE-1 := 0;
    signal BYTES_COUNTER  : integer range 0 to BUFFER_SIZE-1 := 0;

    signal tx_valid_i     : std_logic := '0';
    signal tx_byte_i      : std_logic_vector(7 downto 0) := (others => '0');
    signal input_reg      : std_logic_vector(7 downto 0) := (others => '0');

begin

    -- State register
    process(CLK, RESET)
    begin
        if RESET = '1' then
            STATE <= IDLE;
        elsif rising_edge(CLK) then
            STATE <= NEXT_STATE;
        end if;
    end process;

    -- Next state logic (combinatorial)
    process(STATE, RX_VALID, BYTES_COUNTER, BYTES_EXPECTED, COMMAND_TYPE)
    begin
        NEXT_STATE <= STATE;
        
        case STATE is
            when IDLE =>
                if RX_VALID = '1' then
                    NEXT_STATE <= PARSING;
                end if;
                
            when PARSING =>
                if BYTES_COUNTER = BYTES_EXPECTED then
                    NEXT_STATE <= DISPATCH;
                elsif RX_VALID = '1' and BYTES_COUNTER >= BUFFER_SIZE-1 then
                    NEXT_STATE <= ERROR_STATE;  -- Buffer overflow
                end if;
                
            when DISPATCH =>
                NEXT_STATE <= IDLE;  -- Always return to IDLE after dispatch
                
            when ERROR_STATE =>
                NEXT_STATE <= IDLE;  -- Reset after error
                
        end case;
    end process;

    -- Data path and control signals (registered)
    process(CLK, RESET)
    begin
        if RESET = '1' then
            COMMAND_BYTE   <= (others => '0');
            COMMAND_TYPE   <= (others => '0');
            BYTES_EXPECTED <= 0;
            BYTES_COUNTER  <= 0;
            input_reg      <= (others => '0');
            tx_byte_i      <= (others => '0');
            tx_valid_i     <= '0';
            
        elsif rising_edge(CLK) then
            -- Default values
            tx_valid_i <= '0';
            
            case STATE is
                when IDLE =>
                    if RX_VALID = '1' then
                        COMMAND_BYTE <= DATA_IN;
                        COMMAND_TYPE <= DATA_IN(7 downto 4);
                        
                        -- Limit bytes expected to buffer size
                        if unsigned(DATA_IN(3 downto 0)) > BUFFER_SIZE-1 then
                            BYTES_EXPECTED <= BUFFER_SIZE-1;
                        else
                            BYTES_EXPECTED <= to_integer(unsigned(DATA_IN(3 downto 0)));
                        end if;
                        
                        BYTES_COUNTER <= 0;
                    end if;
                    
                when PARSING =>
                    if RX_VALID = '1' then
                        if BYTES_COUNTER < BUFFER_SIZE then
                            CMD_BUFFER(BYTES_COUNTER) <= DATA_IN;
                            BYTES_COUNTER <= BYTES_COUNTER + 1;
                        end if;
                    end if;
                    
                when DISPATCH =>
                    case COMMAND_TYPE is
                        when "0010" =>  -- Read input command (0x2_)
                            tx_byte_i  <= input_reg;
                            tx_valid_i <= '1';
                            
                        when "0100" =>  -- Write command (0x4_)
                            -- Store first byte in input_reg
                            if BYTES_EXPECTED > 0 then
                                input_reg <= CMD_BUFFER(0);
                            end if;
                            tx_byte_i  <= x"00";  -- Acknowledge
                            tx_valid_i <= '1';
                            
                        when others =>
                            -- Send error code for invalid command
                            tx_byte_i  <= x"FF";
                            tx_valid_i <= '1';
                    end case;
                    
                when ERROR_STATE =>
                    -- Send buffer overflow error
                    tx_byte_i  <= x"FE";  -- Buffer overflow error
                    tx_valid_i <= '1';
                    
            end case;
        end if;
    end process;

    -- Output registers
    process(CLK, RESET)
    begin
        if RESET = '1' then
            tx_data       <= (others => '0');
            tx_data_valid <= '0';
        elsif rising_edge(CLK) then
            tx_data_valid <= tx_valid_i;
            if tx_valid_i = '1' then
                tx_data <= tx_byte_i;
            end if;
        end if;
    end process;

end Behavioral;
