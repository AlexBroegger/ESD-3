library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity RX is
    port (
        clk        : in  std_logic; -- Giver sig selv
        reset      : in  std_logic; -- Reset knap, den skal bare være der
        rx_line    : in  std_logic; -- Incoming fra TX line
        rx_data    : out STD_LOGIC_VECTOR(7 downto 0); -- Bliver samplet med shift register
        rx_ready   : out std_logic; -- Bare om han er klar
        parity_enable : in std_logic; -- parity_enable = 0 er slukket for parity, og tændte for = 1
        parity_m : in std_logic; -- parity_m = 0 er even parity, parity_m = 1 er odd parity
        parity_valid : out std_logic -- parity_valid = 0, fanget parity bit er falsk, ellers er det sandt
    );
end RX;

architecture rtl of RX is
-- States
    type Rstate is (IDLE, START, DATA, PARITY,STOP);
    signal state, next_state : Rstate;

    signal rx_sync_1, rx_sync_2 : std_logic; -- 2ff

    signal shift_reg : STD_LOGIC_VECTOR(7 downto 0);
    signal bit_count : integer range 0 to 7;

-- Sample 
    constant oversample       : integer := 16; -- Vores valgte oversampling rate. Vi har 16 gange oversampling
    constant clock_p_16x      : integer := 78 ; -- Dette er 12MHz/(9600*16)=78.125, og vi runder ned. Dette betyder der kommer lidt tidsdrift
    signal os_count           : integer range 0 to 77; -- Tæller op til
    signal os_tick            : std_logic; -- Bliver en når vi når til 78

    signal sample_count : integer range 0 to 15;

-- flag signaler
    signal shift_en     : std_logic; -- Tillader shift
    signal done_sample  : std_logic; -- Færdig med at sample
    signal sample_parity : std_logic; -- Flag til at sample

-- Parity signaler
    signal paritys : std_logic; -- beregnet parity værdi
    signal paritys_sampled : std_logic; -- Samplet parity værdi


    
    -- Parity Funktion (bare så det ikke bliver så skide grimt....)
    function parity_check (data: std_logic_vector; parity_bit: STD_LOGIC; parity_mode: STD_LOGIC ) return BOOLEAN is variable p : std_logic := '0';
    begin
        for i in data'range loop
            p := p xor data(i);
        end loop;

        if parity_mode = '1' then -- Odd
            p := not p; 
        end if;

        return (p = parity_bit);
    end function;

begin

    --2ff, bruges til metastability problemer
    sync_proc : process(clk, reset)
    begin
        if reset='1' then
            rx_sync_1 <= '1';
            rx_sync_2 <= '1';
        elsif rising_edge(clk) then
            rx_sync_1 <= rx_line;
            rx_sync_2 <= rx_sync_1;
        end if;
    end process;

    -- Oversamplings count. Lidt ligesom baud generator, men den kører 16 gange hurtigere, dette bliver vores nye baud_tick. Det vil sige at 16 af disse giver 16 ticks.
    os_baud : process(clk, reset)
    begin
        if reset = '1' then
            os_count <= 0;
            os_tick  <= '0';
        elsif rising_edge(clk) then
            os_tick <= '0';
            if os_count = 77 then
                os_count <= 0;
                os_tick  <= '1';
            else
                os_count <= os_count + 1;
            end if;
        end if;
    end process;

    -- State register og lidt datapath
    reg_proc : process(clk, reset)
    begin
        if reset='1' then
            state        <= IDLE;
            shift_reg    <= (others=>'0');
            bit_count    <= 0;
            sample_count <= 0;
            rx_data      <= (others=>'0');
            paritys <= '0';

        elsif rising_edge(clk) then
            state <= next_state;

            -- Hold sample_count 0 hele tiden. Dette gøres for at sikre lidt bedre timing
            if state = IDLE then
                sample_count <= 0;
                bit_count    <= 0; -- Reset
            
            elsif os_tick='1' then
                -- Standard counter that wraps around
                if sample_count = 15 then
                    sample_count <= 0;
                    -- Ingen tick fordi det ikke skal bruges, vi skal bare tælle ticks
                else
                    sample_count <= sample_count + 1;
                end if;

                -- Data shift
                if shift_en='1' then
                    shift_reg <= rx_sync_2 & shift_reg(7 downto 1); -- Concatetion (tror det hedder det)
                    bit_count <= bit_count + 1; -- bit_count styring
                end if;
                if sample_parity = '1' then 
                    paritys <= rx_sync_2; 

                end if;
                -- rx_data bliver kun til hele shift_reg når sampling er færdig
                if done_sample='1' then
                    rx_data <= shift_reg;
                    if parity_enable = '1' then
                        if parity_check(shift_reg, paritys, parity_m) then
                            parity_valid <= '1';
                        else
                            parity_valid <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- State transition logik
    next_state_proc : process(state, rx_sync_2, bit_count, sample_count, os_tick)
    begin
        next_state <= state;

        case state is
            when IDLE =>
                if rx_sync_2 = '0' then
                    next_state <= START;
                end if;

            when START =>
                -- Vi tjekker midten af bit.
                if os_tick='1' and sample_count = 8 then
                    if rx_sync_2='0' then
                        next_state <= DATA;
                    else
                        next_state <= IDLE; -- Sikrer at det ikke er en falsk start
                    end if;
                end if;

            when DATA =>
                if os_tick='1' and sample_count = 8 then
                    if bit_count = 7 and parity_enable = '0' then
                        next_state <= STOP;
                    elsif bit_count = 7 and parity_enable = '1' then
                        next_state <= PARITY;
                    end if;
                end if;

            when PARITY =>
                if os_tick = '1' and sample_count = 8 then
                    next_state <= STOP;
                end if;

            when STOP =>
                if os_tick='1' and sample_count = 8 then
                    next_state <= IDLE;
                end if;

        end case;
    end process;

    -- Output logik
    out_proc : process(state, sample_count, os_tick)
    begin
        rx_ready    <= '0';
        shift_en    <= '0';
        done_sample <= '0';
        sample_parity <= '0';

        case state is
            when IDLE =>
            -- Intet
            when START =>
            -- Intet
            when DATA =>
                if os_tick='1' and sample_count = 8 then
                    shift_en <= '1';
                end if;

            when PARITY =>
                if os_tick= '1' and sample_count = 8 then
                    sample_parity <= '1';
                end if;

            when STOP =>
                if os_tick='1' and sample_count = 8 then
                    rx_ready    <= '1';
                    done_sample <= '1';
                end if;
        end case;
    end process;

end rtl;
