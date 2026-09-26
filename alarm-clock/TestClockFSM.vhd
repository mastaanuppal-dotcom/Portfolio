-- Mastaan Uppal, Eugene Magsino

library ieee;
use ieee.std_logic_1164.all;

-- verifies the one hot mode sequence, the field sequence and the
-- field reset that happens on every mode change
entity TestClockFSM is
end entity TestClockFSM;

architecture Behavioral of TestClockFSM is

    component ClockFSM is
        port ( clk, rst, mode_key, field_key : in std_logic;
               mode, field : out std_logic_vector(2 downto 0) );
    end component;

    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';
    signal mode_key  : std_logic := '0';
    signal field_key : std_logic := '0';
    signal mode      : std_logic_vector(2 downto 0);
    signal field     : std_logic_vector(2 downto 0);

    signal done : boolean := false;

begin

    dut : ClockFSM
        port map ( clk => clk, rst => rst,
                   mode_key => mode_key, field_key => field_key,
                   mode => mode, field => field );

    clk_gen : process
    begin
        while not done loop
            clk <= '0'; wait for 10 ns;
            clk <= '1'; wait for 10 ns;
        end loop;
        wait;
    end process;

    stimulus : process
        -- one cycle pulse on the mode input
        procedure pulse_mode is
        begin
            mode_key <= '1';
            wait until rising_edge(clk);
            mode_key <= '0';
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

        -- one cycle pulse on the field input
        procedure pulse_field is
        begin
            field_key <= '1';
            wait until rising_edge(clk);
            field_key <= '0';
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';
        wait for 1 ns;

        assert mode = "001" report "reset mode is not display" severity error;
        assert field = "001" report "reset field is not seconds" severity error;

        -- full mode cycle display -> set time -> set alarm -> display
        pulse_mode;
        assert mode = "010" report "mode did not enter set time" severity error;

        pulse_mode;
        assert mode = "100" report "mode did not enter set alarm" severity error;

        pulse_mode;
        assert mode = "001" report "mode did not return to display" severity error;

        -- field cycle seconds -> minutes -> hours -> seconds
        pulse_mode;  -- into set time so the field is meaningful
        pulse_field;
        assert field = "010" report "field did not move to minutes" severity error;

        pulse_field;
        assert field = "100" report "field did not move to hours" severity error;

        pulse_field;
        assert field = "001" report "field did not wrap to seconds" severity error;

        -- field must reset to seconds on a mode change
        pulse_field;  -- field is now minutes
        pulse_mode;   -- move to set alarm
        assert mode = "100" report "mode did not enter set alarm" severity error;
        assert field = "001" report "field did not reset on mode change" severity error;

        report "testclockfsm finished, all checks passed";
        done <= true;
        wait;
    end process;

end architecture Behavioral;
