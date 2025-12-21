library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_System_Top is
    Port (
        CLK     : in  std_logic;
        RESET   : in  std_logic;
        RX_LINE : in  std_logic;
        TX_LINE : out std_logic
    );
end UART_System_Top;

architecture Structural of UART_System_Top is

    -- Internal signals
    signal rx_data       : std_logic_vector(7 downto 0);
    signal rx_ready      : std_logic;
    signal tx_data       : std_logic_vector(7 downto 0);
    signal tx_data_valid : std_logic;

begin

    -- Component instantiations
    RX_inst : entity work.RX
    port map (
        clk     => CLK,
        reset   => RESET,
        rx_line => RX_LINE,
        rx_data => rx_data,
        rx_ready => rx_ready
    );

    PARSER_inst : entity work.UART_parser
    port map (
        CLK           => CLK,
        RESET         => RESET,
        DATA_IN       => rx_data,
        RX_VALID      => rx_ready,
        tx_data       => tx_data,
        tx_data_valid => tx_data_valid
    );

    TX_inst : entity work.TX
    port map (
        clk            => CLK,
        reset          => RESET,
        data_available => tx_data_valid,
        tx_line        => TX_LINE,
        tx_data        => tx_data
        -- tx_busy removed
    );

end Structural;
