library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port (
        clk        : in  STD_LOGIC;             -- 12 MHz system clock
        rst        : in  STD_LOGIC;             -- active-high reset

        -- FAST DETECTION PINS (used for protocol detection)
        I2C_ENA    : in  STD_LOGIC;
        SPI_CS_IN  : in  STD_LOGIC;
        UART_RX_IN : in  STD_LOGIC;

        -- Pin configuration: 00 = hi-Z, 01 = I2C, 10 = SPI, 11 = UART
        MUX_SELECT : buffer STD_LOGIC_VECTOR(1 downto 0);

        -- Universal pins (shared physical pins)
        U_Pin_1 : inout STD_LOGIC;  -- SCL / SCLK / UART TX
        U_Pin_2 : inout STD_LOGIC;  -- SDA / MISO
        U_Pin_3 : inout STD_LOGIC;  -- MOSI

        -- Debug output
        DEBUG_OUT : out STD_LOGIC_VECTOR(7 downto 0);
        
        -- TEST
        test_port : out STD_LOGIC;
       
       -- ERROR
        protocol_error : out STD_LOGIC
        
    );
end top;

architecture Behavioral of top is

    ----------------------------------------------------------------------------
    -- Components
    ----------------------------------------------------------------------------
    component SPI_slave
        Port (
            SCLK: in  std_logic;
            MOSI: in  std_logic;
            MISO: out std_logic;
            CS  : in  std_logic;
            mosi_out : out std_logic_vector(7 downto 0);
            byte_ready_port : out std_logic;
            clk             : in std_logic
        );
    end component;

    component RX
        Port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            rx_line      : in  std_logic;
            rx_data      : out STD_LOGIC_VECTOR(7 downto 0);
            rx_ready     : out std_logic;
            parity_enable: in  std_logic;
            parity_m     : in  std_logic;
            parity_valid : out std_logic;
            rx_test      : out std_logic
        );
    end component;

    component i2c_Master
        Port (
            clk       : in std_logic;
            reset     : in std_logic;
            ena       : in std_logic;
            rw        : in std_logic;
            s_addr    : in std_logic_vector(6 downto 0);
            write_in  : in std_logic_vector(7 downto 0);
            new_input : out std_logic;
            read_out  : out std_logic_vector(7 downto 0);
            busy      : out std_logic;
            ack_error : out std_logic;
            sda       : inout std_logic;
            scl       : inout std_logic
        );
    end component;

    ----------------------------------------------------------------------------
    -- Internal signals
    ----------------------------------------------------------------------------
    -- SPI
    signal spi_sclk_int, spi_mosi_int : std_logic := '0';
    signal spi_miso_int, spi_cs_int   : std_logic := 'Z';
    signal spi_data_out               : std_logic_vector(7 downto 0) := (others => '0');
    signal spi_ready                  : std_logic := '0';

    -- UART
    signal uart_tx_int  : std_logic := 'Z';
    signal uart_data    : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_ready   : std_logic := '0';
    signal uart_rx_int  : std_logic := '1';

    -- I2C
    signal i2c_scl_int, i2c_sda_int : std_logic := 'Z';
    signal i2c_ena_int : std_logic := '0';
    signal i2c_rw      : std_logic := '0';
    signal i2c_addr    : std_logic_vector(6 downto 0) := (others => '0');
    signal i2c_data_in, i2c_data_out : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_busy_sig, i2c_ack_err_sig, i2c_new_input : std_logic := '0';

    -- FSM
    type fsm_state_type is (IDLE_MONITOR, ACTIVE_I2C, ACTIVE_SPI, ACTIVE_UART);
    signal state_reg, state_next : fsm_state_type := IDLE_MONITOR;

    -- Universal pin drivers
    signal u1_out, u2_out, u3_out : std_logic := 'Z';
    signal u1_oe, u2_oe, u3_oe    : std_logic := '0';

    -- Debug register
    signal debug_reg : std_logic_vector(7 downto 0) := (others => '0');

    -- ACTIVITY DETECTION
    signal I2C_ACTIVITY_DETECTED : STD_LOGIC := '0';
    signal SPI_ACTIVITY_DETECTED : STD_LOGIC := '0';
    signal UART_ACTIVITY_DETECTED : STD_LOGIC := '0';

    signal i2c_sda_prev : STD_LOGIC := '1'; 
    signal spi_cs_prev  : STD_LOGIC := '1';
    signal uart_rx_prev : STD_LOGIC := '1';

    -- Pin readback signals
    signal u1_pin_in, u2_pin_in, u3_pin_in : std_logic;
    

    -- Error checking
    signal error_uart, error_spi, error_i2c : std_logic := '0';
    signal uart_error_latched, spi_error_latched, i2c_error_latched : std_logic := '0';
    signal protocol_error_signal : std_logic := '0';
    
    -- TEST
    signal led_test : std_logic;
    signal rx_sync_0 : std_logic := '1';
    signal rx_sync_1 : std_logic := '1';
    
    signal cs_sync_0 : std_logic := '1';
    signal cs_sync_1 : std_logic := '1';

    signal ena_sync_0 : std_logic := '1';
    signal ena_sync_1 : std_logic := '1';

    signal test_sig   : std_logic := '0';
    signal u1_prev    : std_logic;
    signal u3_prev    : std_logic;

begin

    spi_cs_int <= SPI_CS_IN;
    uart_rx_int <= UART_RX_IN;
    i2c_ena_int <= I2C_ENA;

    -- Always Read Ports
    i2c_scl_int  <= u1_pin_in;    -- SCL line for I2C (bidirectional)
    spi_sclk_int <= u1_pin_in;    -- SPI SCLK (input)
    i2c_sda_int  <= u2_pin_in;    -- SDA line for I2C (bidirectional)
    spi_mosi_int <= u3_pin_in;    -- SPI MOSI (input)





    -- Map tri-state drivers to physical pins
    U_Pin_1 <= u1_out when u1_oe = '1' else 'Z';
    U_Pin_2 <= u2_out when u2_oe = '1' else 'Z';
    U_Pin_3 <= u3_out when u3_oe = '1' else 'Z';

    -- Always sample physical pins
    u1_pin_in <= U_Pin_1;
    u2_pin_in <= U_Pin_2;
    u3_pin_in <= U_Pin_3;
    


    -- Simple detection logic 

process(clk)
begin
    if rising_edge(clk) then
    
        rx_sync_0 <= UART_RX_IN;
        rx_sync_1 <= rx_sync_0;
    
        cs_sync_0 <= SPI_CS_IN;
        cs_sync_1 <= cs_sync_0;
               
       
        uart_rx_prev <= rx_sync_1;
        spi_cs_prev <= cs_sync_1;        
        
        
        if rx_sync_1 = '0' and uart_rx_prev = '1' then
            UART_ACTIVITY_DETECTED <= '1';
        else
            UART_ACTIVITY_DETECTED <= '0';
        end if;

    
        if cs_sync_1 = '0' and spi_cs_prev = '1' then
            SPI_ACTIVITY_DETECTED <= '1';
        else
            SPI_ACTIVITY_DETECTED <= '0';
        end if;

    
        if I2C_ENA = '1' then
            I2C_ACTIVITY_DETECTED <= '1';
        else
            I2C_ACTIVITY_DETECTED <= '0';
        end if;
    end if;   
 
end process;



-- NEXT STATE LOGIC
process(state_reg, I2C_ACTIVITY_DETECTED, SPI_ACTIVITY_DETECTED, UART_ACTIVITY_DETECTED)
begin
    state_next <= state_reg;

    case state_reg is
        when IDLE_MONITOR =>
            if I2C_ACTIVITY_DETECTED = '1' and SPI_ACTIVITY_DETECTED = '0' and UART_ACTIVITY_DETECTED = '0' then
                state_next <= ACTIVE_I2C;
            elsif SPI_ACTIVITY_DETECTED = '1' and I2C_ACTIVITY_DETECTED = '0' and UART_ACTIVITY_DETECTED = '0' then
                state_next <= ACTIVE_SPI;
            elsif UART_ACTIVITY_DETECTED = '1' and SPI_ACTIVITY_DETECTED = '0' and I2C_ACTIVITY_DETECTED = '0' then
                state_next <= ACTIVE_UART;
            end if;

        when ACTIVE_I2C  => state_next <= ACTIVE_I2C;
        when ACTIVE_SPI  => state_next <= ACTIVE_SPI;
        when ACTIVE_UART => state_next <= ACTIVE_UART;

        when others =>
            state_next <= IDLE_MONITOR;
    end case;
end process;

-- FSM register
process(clk, rst)
begin
    if rst = '1' then
        state_reg <= IDLE_MONITOR;
    elsif rising_edge(clk) then
        state_reg <= state_next;
    end if;
end process;

-- Output Logic
process(state_reg)
begin
    case state_reg is
        when IDLE_MONITOR => MUX_SELECT <= "00";
        when ACTIVE_I2C   => MUX_SELECT <= "01";
        when ACTIVE_SPI   => MUX_SELECT <= "10";
        when ACTIVE_UART  => MUX_SELECT <= "11";
        when others       => MUX_SELECT <= "00";
    end case;
end process;


-- Multiplexing
process(MUX_SELECT, i2c_scl_int, i2c_sda_int, spi_sclk_int, spi_miso_int, spi_mosi_int, uart_tx_int)
begin
    -- Defaults to high-impedance
    u1_out <= 'Z'; u1_oe <= '0';
    u2_out <= 'Z'; u2_oe <= '0';
    u3_out <= 'Z'; u3_oe <= '0';

    case MUX_SELECT is
        when "01" =>  -- I2C
            u1_out <= i2c_scl_int; u1_oe <= '1';
            u2_out <= i2c_sda_int; u2_oe <= '1';
        when "10" =>  -- SPI
            u2_out <= spi_miso_int; u2_oe <= '1';
        when "11" =>  -- UART
            u2_out <= uart_tx_int; u2_oe <= '1';
        when others =>
            null; -- already Z
    end case;
end process;

    ----------------------------------------------------------------------------
    -- Pin-Level Error Detection
    ----------------------------------------------------------------------------
    process(clk)
    begin
    if rising_edge(clk) then
    u1_prev <= u1_pin_in;
    u3_prev <= u3_pin_in;
    end if;
    end process;
    
    process(clk, rst)
    begin
        if rst = '1' then
            uart_error_latched <= '0';
            spi_error_latched  <= '0';
            i2c_error_latched  <= '0';
            protocol_error_signal     <= '0';
        elsif rising_edge(clk) then

            -- Reset per-cycle flags
            error_uart <= '0';
            error_spi  <= '0';

            case state_reg is
                when ACTIVE_UART =>
                    if SPI_CS_IN = '0' then
                        error_uart <= '1';
                    end if;

                    if I2C_ENA = '1' then
                        error_uart <= '1';
                    end if;

                    if u1_pin_in /= u1_prev then
                        error_uart <= '1';
                    end if;

                    if u3_pin_in /= u3_prev then
                        error_uart <= '1';
                    end if;

                when ACTIVE_SPI =>
                    if (I2C_ENA = '1') or (UART_RX_IN= '0') then
                        error_spi <= '1';
                    end if;

                when ACTIVE_I2C =>
                    if i2c_ack_err_sig = '1' then
                        i2c_error_latched <= i2c_ack_err_sig;
                    end if;
                    if (SPI_CS_IN = '0') or (UART_RX_IN = '0') then
                        error_spi <= '1';
                    end if;

                when others =>
                    null;
            end case;

            -- Latch UART and SPI errors
            if error_uart = '1' then
                uart_error_latched <= '1';
            end if;

            if error_spi = '1' then
                spi_error_latched <= '1';
            end if;

            -- Combine errors
            protocol_error_signal <= uart_error_latched or spi_error_latched or i2c_error_latched;
        end if;
    end process;

protocol_error <= protocol_error_signal;

-- Debug capture
process(clk, rst)
begin
    if rst = '1' then
        debug_reg <= (others => '0');
    elsif rising_edge(clk) then
        if state_reg = ACTIVE_UART and uart_ready = '1' then
            debug_reg <= uart_data;
        elsif state_reg = ACTIVE_SPI and spi_ready = '1' then
            debug_reg <= spi_data_out;
        elsif state_reg = ACTIVE_I2C and i2c_busy_sig = '0' then
            debug_reg <= i2c_data_out;
        end if;
    end if;
end process;

DEBUG_OUT <= debug_reg;

-- TEST
-- test_port <= uart_rx_int; -- virker
test_port <= test_sig;
-- test_port <= uart_data(0);   


-- Protocol instances
SPI_slave_inst : SPI_slave
    Port Map (
        SCLK => spi_sclk_int,
        MOSI => spi_mosi_int,
        MISO => spi_miso_int,
        CS   => spi_cs_int,
        mosi_out => spi_data_out,
        byte_ready_port => spi_ready,
        clk             => clk
    );

UART_inst : RX
    port map(
        clk => clk,
        reset => rst,
        rx_line => uart_rx_int,
        rx_data => uart_data,
        rx_ready => uart_ready,
        parity_enable => '0',
        parity_m => '0',
        parity_valid => open,
        rx_test => test_sig
    );

I2C_master_inst : I2C_Master
    Port Map(
        clk       => clk,
        reset     => rst,
        ena       => i2c_ena_int,
        rw        => i2c_rw,
        s_addr    => i2c_addr,
        write_in  => i2c_data_in,
        new_input => i2c_new_input,
        read_out  => i2c_data_out,
        busy      => i2c_busy_sig,
        ack_error => i2c_ack_err_sig,
        sda       => i2c_sda_int,
        scl       => i2c_scl_int
    );

end Behavioral;
