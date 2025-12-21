library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_parser is
    Port (
        CLK           : in  std_logic;
        RESET         : in  std_logic;
        DATA_IN       : in  std_logic_vector(7 downto 0);
        RX_VALID      : in  std_logic;
        
        FIFO_IN       : out std_logic_vector(16 downto 0);
        FIFO_IN_valid : out std_logic;
        
        tx_data       : out std_logic_vector(7 downto 0);
        tx_data_valid : out std_logic;
        data_input_1  : in  std_logic_vector(7 downto 0)  -- connected to I2C read output
    );
end UART_parser;

architecture Behavioral of UART_parser is

    type PARSER_STATE_TYPE is (IDLE, PARSING, DISPATCH);
    signal STATE, NEXT_STATE : PARSER_STATE_TYPE := IDLE;

    signal COMMAND_BYTE   : std_logic_vector(7 downto 0) := (others => '0');
    signal COMMAND_TYPE   : std_logic_vector(3 downto 0) := (others => '0');
    signal BYTES_EXPECTED : integer range 0 to 255 := 0;
    signal BYTES_COUNTER  : integer range 0 to 255 := 0;

    type BYTE_ARRAY is array (0 to 255) of std_logic_vector(7 downto 0);
    signal CMD_BUFFER     : BYTE_ARRAY := (others => (others => '0'));
    
    signal tx_valid       : std_logic := '0';
    signal tx_byte        : std_logic_vector(7 downto 0) := (others => '0');

    signal NUM_I2C_CMDS   : integer range 0 to 255 := 0;
    signal CMD_IDX        : integer range 0 to 255 := 0;

    signal FIFO_word      : std_logic_vector(16 downto 0) := (others => '0');
    signal FIFO_pulse     : std_logic := '0';

begin
    tx_data       <= tx_byte;
    tx_data_valid <= tx_valid;
    FIFO_IN       <= FIFO_word;
    FIFO_IN_valid <= FIFO_pulse;

    -- State register
    process(CLK, RESET)
    begin
        if RESET = '1' then
            STATE <= IDLE;
        elsif rising_edge(CLK) then
            STATE <= NEXT_STATE;
        end if;
    end process;

    -- Main FSM
    process(CLK, RESET)
    begin
        if RESET = '1' then
            NEXT_STATE      <= IDLE;
            BYTES_EXPECTED  <= 0;
            BYTES_COUNTER   <= 0;
            COMMAND_BYTE    <= (others => '0');
            COMMAND_TYPE    <= (others => '0');
            NUM_I2C_CMDS    <= 0;
            CMD_IDX         <= 0;
            FIFO_word       <= (others => '0');
            FIFO_pulse      <= '0';
            tx_byte         <= (others => '0');
            tx_valid        <= '0';
        elsif rising_edge(CLK) then

            -- default: pulse low
            FIFO_pulse <= '0';
            tx_valid   <= '0';

            case STATE is
                when IDLE =>
                    if RX_VALID = '1' then
                        COMMAND_BYTE   <= DATA_IN;
                        COMMAND_TYPE   <= DATA_IN(7 downto 4);
                        BYTES_EXPECTED <= to_integer(unsigned(DATA_IN(3 downto 0)));
                        BYTES_COUNTER  <= 0;
                        NEXT_STATE     <= PARSING;
                    else
                        NEXT_STATE <= IDLE;
                    end if;

                when PARSING =>
                    if RX_VALID = '1' then
                        CMD_BUFFER(BYTES_COUNTER) <= DATA_IN;
                        BYTES_COUNTER <= BYTES_COUNTER + 1;

                        if BYTES_COUNTER + 1 = BYTES_EXPECTED then
                            NUM_I2C_CMDS <= BYTES_EXPECTED / 2;
                            CMD_IDX      <= 0;
                            NEXT_STATE   <= DISPATCH;
                        else
                            NEXT_STATE <= PARSING;
                        end if;
                    else
                        NEXT_STATE <= PARSING;
                    end if;

                when DISPATCH =>
                    case COMMAND_TYPE is
                        when "0001" =>  -- I2C write command
                            if CMD_IDX < NUM_I2C_CMDS then
                                FIFO_word  <= '1' &                          -- ena
                                              CMD_BUFFER(CMD_IDX*2)(0) &      -- rw
                                              CMD_BUFFER(CMD_IDX*2)(7 downto 1) & -- s_addr
                                              CMD_BUFFER(CMD_IDX*2 + 1);       -- write_in
                                FIFO_pulse <= '1';  -- one-clock pulse
                                CMD_IDX    <= CMD_IDX + 1;
                                NEXT_STATE <= DISPATCH;
                            else
                                FIFO_word  <= (others => '0');  -- optional: last word all zeros
                                FIFO_pulse <= '1';
                                NEXT_STATE <= IDLE;
                            end if;

                        when "0010" =>  -- Read input command
                            tx_byte   <= data_input_1;
                            tx_valid  <= '1';
                            NEXT_STATE <= IDLE;

                        when others =>
                            FIFO_word  <= (others => '0');  -- optional: all zeros
                            FIFO_pulse <= '1';
                            NEXT_STATE <= IDLE;
                    end case;

            end case;
        end if;
    end process;

end Behavioral;
