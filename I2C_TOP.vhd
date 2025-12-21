library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TOP_I2C_UI is
    Port (
        clk       : in  std_logic;
        reset     : in  std_logic;

        -- UART - usb
        rx_line: in  std_logic;
        tx_line: out std_logic;

        -- I2C
        scl       : inout std_logic;
        sda       : inout std_logic
    );
end TOP_I2C_UI;

architecture rtl of TOP_I2C_UI is

    -- UART RX/TX signals
    signal rx_data        : unsigned(7 downto 0);
    signal rx_ready       : std_logic;
    signal tx_data        : std_logic_vector(7 downto 0);
    signal tx_data_valid  : std_logic;

    -- Parser to FIFO signals
    signal FIFO_IN        : std_logic_vector(16 downto 0);
    signal FIFO_IN_valid  : std_logic;

    -- FIFO to I2C Master signals
    signal FIFO_wr_en     : std_logic;
    signal ena            : std_logic;
    signal rw             : std_logic;
    signal s_addr         : std_logic_vector(6 downto 0);
    signal write_in       : std_logic_vector(7 downto 0);
    signal FIFO_full      : std_logic;
    signal FIFO_empty     : std_logic;

    -- I2C signals
    signal read_out       : std_logic_vector(7 downto 0);
    signal busy           : std_logic;
    signal ack_error      : std_logic;

begin

    -- RX UART
    RX_inst: entity work.RX
        port map(
            clk      => CLK,
            reset    => RESET,
            rx_line  => RX_line,
            rx_data  => rx_data,
            rx_ready => rx_ready
        );

    -- TX UART
    TX_inst: entity work.TX
        port map(
            clk            => CLK,
            reset          => RESET,
            data_available => tx_data_valid,
            tx_line        => TX_line,
            tx_data        => unsigned(tx_data),
            tx_busy        => open
        );

    -- UART Parser
    Parser_inst: entity work.UART_parser
        port map(
            CLK           => CLK,
            RESET         => RESET,
            DATA_IN       => std_logic_vector(rx_data),
            RX_VALID      => rx_ready,
            FIFO_IN       => FIFO_IN,
            FIFO_IN_valid => FIFO_IN_valid,
            tx_data       => tx_data,
            tx_data_valid => tx_data_valid,
            data_input_1  => read_out
        );

    -- FIFO
    FIFO_inst: entity work.FIFO_I2C
        generic map(
            DEPTH => 16
        )
        port map(
            clk      => CLK,
            rst      => RESET,
            wr_en    => FIFO_IN_valid,
            data_in  => FIFO_IN,
            new_input => ena,  -- I2C Master pops command when ready
            ena      => ena,
            rw       => rw,
            s_addr   => s_addr,
            write_in => write_in,
            full     => FIFO_full,
            empty    => FIFO_empty
        );

    -- I2C Master
    I2C_inst: entity work.I2C_Master
        port map(
            clk       => CLK,
            reset     => RESET,
            ena       => ena,
            rw        => rw,
            s_addr    => s_addr,
            write_in  => write_in,
            new_input => open,  -- handled by FIFO internally
            read_out  => read_out,
            busy      => busy,
            ack_error => ack_error,
            sda       => SDA,
            scl       => SCL
        );

end rtl;


