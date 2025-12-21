library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TXRXTOP is
    port(
       Clk : in std_logic;
       RST : in std_logic;
       tx_line : out std_logic;
       rx_line : in std_logic
);
       
end TXRXTOP;

architecture Behavioral of TXRXTOP is
    signal rx_data        : unsigned(7 downto 0);
    signal rx_ready       : std_logic;
    signal tx_data        : std_logic_vector(7 downto 0);
    signal tx_data_valid  : std_logic;

       
begin
    -- RX UART
    RX_inst: entity work.RX
        port map(
            clk      => CLK,
            reset      => RST,
            rx_line  => RX_line,
            rx_data  => rx_data,
            rx_ready => rx_ready
        );
    TX_inst: entity work.TX
        port map(
            clk            => CLK,
            reset          => RST,
            data_available => tx_data_valid,
            tx_line        => TX_line,
            tx_data        => unsigned(tx_data),
            tx_busy        => open
        );     
    Parser_inst: entity work.UART_parser
        port map(
            CLK           => CLK,
            RESET         => RST,
            DATA_IN       => std_logic_vector(rx_data),
            RX_VALID      => rx_ready,
            tx_data       => tx_data,
            tx_data_valid => tx_data_valid
        );

end Behavioral;
