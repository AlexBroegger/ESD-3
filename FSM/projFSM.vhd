-- Fil: projFSM.vhd 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.control_constants.all;

entity projFSM is
    Port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        -- Ekstern I/O (Systemets U_Pin I/O)
        u_pin_io : inout STD_LOGIC_VECTOR(7 downto 0);
        protocol_active_led : out STD_LOGIC_VECTOR(1 downto 0)
    );
end projFSM;

architecture Behavioral of projFSM is


    -- 1. KOMPONENTDEKLARATIONER 

    
    component reconfig_interface is
        Port (
            clk         : in    STD_LOGIC;
            reset_n     : in    STD_LOGIC;
            reconfig_i  : in    STD_LOGIC_VECTOR(1 downto 0);
            reconfig_o  : out   STD_LOGIC_VECTOR(1 downto 0);
            RM_DATA_OUT : out   STD_LOGIC_VECTOR(7 downto 0);
            RM_OE       : out   STD_LOGIC_VECTOR(7 downto 0);
            RM_DATA_IN  : in    STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component io_mux is
        Port (
            u_pin_io  : inout STD_LOGIC_VECTOR(7 downto 0);
            rp_data_o : in  STD_LOGIC_VECTOR(7 downto 0);
            rp_oe_o   : in  STD_LOGIC_VECTOR(7 downto 0);
            rp_data_i : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component dpr_controller_wrapper is
        Port (
            clk               : in   STD_LOGIC; 
            reset             : in    STD_LOGIC;
            cfg_sel_in        : in    STD_LOGIC_VECTOR(2 downto 0); 
            cfg_done_out      : out   STD_LOGIC;
            cfg_error_out     : out   STD_LOGIC;
            rm_shutdown_ack   : in    STD_LOGIC; 
            reconfig_i        : in    STD_LOGIC_VECTOR(1 downto 0);
            reconfig_o        : out   STD_LOGIC_VECTOR(1 downto 0)
        );
    end component;




    -- 2. KONSTANTER OG SIGNALER

    -- Til LED test ellers ubrugt
    signal s_protocol_active_led : STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
    
    type T_FSM_STATE is (
        S0_INIT, S1_LOAD_UART, S2_WAIT_LOAD_DONE, S3_TEST_PROTOCOL,
        S4_CHECK_RESULT, S5_LOAD_SPI, S6_LOAD_I2C, S7_PROTOCOL_FOUND, S8_ERROR
    );
    signal state_reg, state_next : T_FSM_STATE := S0_INIT;

    signal cfg_sel_out          : STD_LOGIC_VECTOR(2 downto 0) := (others => '0');
    signal cfg_done_in          : STD_LOGIC := '0';
    signal cfg_error_in         : STD_LOGIC := '0';
    signal rm_shutdown_ack_in   : STD_LOGIC := '0';

    signal reconfig_interface_i : STD_LOGIC_VECTOR(1 downto 0);
    signal reconfig_interface_o : STD_LOGIC_VECTOR(1 downto 0);
    signal fsm_rm_trigger       : STD_LOGIC := '0';

    signal rm_data_in_signal    : STD_LOGIC_VECTOR(7 downto 0);
    signal rm_data_out_signal   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal rm_oe_signal         : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');


begin


    reconfig_interface_o <= (others => '0') when fsm_rm_trigger = '0'
                            else C_START_CMD;


    -- 3. STATE MACHINE OG KONTROLLOGIK



    process(clk)
    begin
    
    
        if reset = '1' then
            state_reg <= S0_INIT;
        elsif rising_edge(clk) then
            state_reg <= state_next;
        end if;
    end process;

    
    process(state_reg, reconfig_interface_i, cfg_done_in, cfg_error_in, rm_shutdown_ack_in, cfg_sel_out, fsm_rm_trigger, s_protocol_active_led)
    begin
        state_next <= state_reg;
        

        
        cfg_sel_out    <= (others => '0');
        fsm_rm_trigger <= '0';


        case state_reg is
            
            when S0_INIT =>
                state_next <= S1_LOAD_UART;
                
                
            when S1_LOAD_UART | S5_LOAD_SPI | S6_LOAD_I2C =>
                
                if state_reg = S1_LOAD_UART then 
                    cfg_sel_out <= "100";
                elsif state_reg = S5_LOAD_SPI then 
                    cfg_sel_out <= "010";
                elsif state_reg = S6_LOAD_I2C then 
                    cfg_sel_out <= "001";
                end if;
               
                state_next <= S2_WAIT_LOAD_DONE; 


            when S2_WAIT_LOAD_DONE =>
                if cfg_done_in = '1' and cfg_error_in = '0' then
                    state_next <= S3_TEST_PROTOCOL;
                elsif cfg_error_in = '1' then
                    state_next <= S8_ERROR;
                end if;


            when S3_TEST_PROTOCOL =>
                s_protocol_active_led <= "01"; -- til test 
                fsm_rm_trigger <= '1'; 
                state_next <= S4_CHECK_RESULT;

            when S4_CHECK_RESULT =>
            fsm_rm_trigger <= '0';
            
                if reconfig_interface_i = C_TEST_SUCCESS then
                    state_next <= S7_PROTOCOL_FOUND;

                elsif reconfig_interface_i = C_TEST_FAILURE then
                    if cfg_sel_out = "100" then 
                        state_next <= S5_LOAD_SPI; 
                    elsif cfg_sel_out = "010" then 
                        state_next <= S6_LOAD_I2C;
                    elsif cfg_sel_out = "001" then 
                        state_next <= S8_ERROR;
                    else
                        state_next <= S8_ERROR;
                    end if;
                end if;

            when S7_PROTOCOL_FOUND =>
                state_next <= S7_PROTOCOL_FOUND;

            when S8_ERROR =>
                state_next <= S8_ERROR;

            when others =>
                state_next <= S0_INIT;

        end case;
    end process;



    -- 4. INSTANSIERINGER

    protocol_active_led <= s_protocol_active_led; -- til LED test

    -- IP interface
    dpr_bd_wrapper_inst : dpr_controller_wrapper
    Port Map (
        clk               => clk,
        reset             => reset,
        cfg_sel_in        => cfg_sel_out,
        cfg_done_out      => cfg_done_in,
        cfg_error_out     => cfg_error_in,
        rm_shutdown_ack   => rm_shutdown_ack_in,
        reconfig_i        => reconfig_interface_i,
        reconfig_o        => open
    );

    -- I/O selektion logik
    io_mux_inst : io_mux
    Port Map (
        u_pin_io  => u_pin_io,
        rp_data_o => rm_data_out_signal,
        rp_oe_o   => rm_oe_signal,
        rp_data_i => rm_data_in_signal
    );

    -- RP
    bus_macro_shell_inst : reconfig_interface
    Port Map (
        clk         => clk,
        reset_n     => not reset,
        reconfig_i  => reconfig_interface_o,
        reconfig_o  => reconfig_interface_i,
        RM_DATA_OUT => rm_data_out_signal,
        RM_OE       => rm_oe_signal,
        RM_DATA_IN  => rm_data_in_signal
    );

end Behavioral;
