-- Mastaan Uppal, Eugene Magsino

library ieee;
use ieee.std_logic_1164.all;

-- integrated test of the full alarm clock
-- small generics are used so one simulated second takes 20 clock cycles
-- the test covers timekeeping, mode changes, pausing while setting the time,
-- setting the alarm, the alarm firing, the soft reset and the hard reset
entity TestAlarmClock is
end entity TestAlarmClock;

architecture Behavioral of TestAlarmClock is

    component AlarmClock is
        generic (
            DEB_MAX    : integer := 500000;
            DIV_NORMAL : integer := 50000000;
            DIV_FAST   : integer := 500000;
            DIV_BLINK  : integer := 6250000
        );
        port (
            CLOCK_50 : in  std_logic;
            KEY      : in  std_logic_vector(3 downto 0);
            SW       : in  std_logic_vector(9 downto 0);
            LEDR     : out std_logic_vector(9 downto 0);
            HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : out std_logic_vector(6 downto 0)
        );
    end component;

    -- active low seven segment patterns for checking the displays
    constant SEG_0 : std_logic_vector(6 downto 0) := "1000000";
    constant SEG_1 : std_logic_vector(6 downto 0) := "1111001";
    constant SEG_2 : std_logic_vector(6 downto 0) := "0100100";
    constant SEG_3 : std_logic_vector(6 downto 0) := "0110000";

    signal clk  : std_logic := '0';
    signal key  : std_logic_vector(3 downto 0) := (others => '1');
    signal sw   : std_logic_vector(9 downto 0) := (others => '0');
    signal ledr : std_logic_vector(9 downto 0);
    signal hex0, hex1, hex2, hex3, hex4, hex5 : std_logic_vector(6 downto 0);

    signal done : boolean := false;

begin

    -- one simulated second is 20 clock cycles, debounce is 2 cycles
    dut : AlarmClock
        generic map (
            DEB_MAX    => 2,
            DIV_NORMAL => 20,
            DIV_FAST   => 4,
            DIV_BLINK  => 10
        )
        port map (
            CLOCK_50 => clk, KEY => key, SW => sw, LEDR => ledr,
            HEX0 => hex0, HEX1 => hex1, HEX2 => hex2,
            HEX3 => hex3, HEX4 => hex4, HEX5 => hex5
        );

    clk_gen : process
    begin
        while not done loop
            clk <= '0'; wait for 10 ns;
            clk <= '1'; wait for 10 ns;
        end loop;
        wait;
    end process;

    stimulus : process
        -- press and release a key, keys are active low on the board
        procedure press(idx : integer) is
        begin
            key(idx) <= '0';
            for i in 1 to 8 loop wait until rising_edge(clk); end loop;
            key(idx) <= '1';
            for i in 1 to 8 loop wait until rising_edge(clk); end loop;
        end procedure;

        variable held : std_logic_vector(6 downto 0);
    begin
        ----------------------------------------------------------------
        -- hard reset and initial state
        ----------------------------------------------------------------
        press(0);
        wait for 1 ns;

        assert hex5 = SEG_1 and hex4 = SEG_2
            report "initial hours are not 12" severity error;
        assert hex3 = SEG_0 and hex2 = SEG_0 and hex1 = SEG_0 and hex0 = SEG_0
            report "initial minutes and seconds are not 00 00" severity error;
        assert ledr(2 downto 0) = "001"
            report "initial mode is not display" severity error;

        ----------------------------------------------------------------
        -- timekeeping, wait for the seconds display to reach 3
        ----------------------------------------------------------------
        wait until hex0 = SEG_3 for 2 us;
        assert hex0 = SEG_3
            report "seconds did not advance to 3" severity error;

        ----------------------------------------------------------------
        -- set time mode pauses the clock
        ----------------------------------------------------------------
        press(1);  -- display -> set time
        wait for 1 ns;
        assert ledr(2 downto 0) = "010"
            report "mode led is not set time" severity error;
        assert ledr(5 downto 3) = "001"
            report "field led is not seconds" severity error;

        held := hex0;
        for i in 1 to 60 loop wait until rising_edge(clk); end loop;
        wait for 1 ns;
        assert hex0 = held
            report "time did not pause in set time mode" severity error;

        -- manual increment of the seconds field
        press(3);
        wait for 1 ns;
        assert hex0 /= held
            report "increment key did not change the seconds" severity error;

        ----------------------------------------------------------------
        -- set alarm mode shows and edits the alarm time
        ----------------------------------------------------------------
        press(1);  -- set time -> set alarm
        wait for 1 ns;
        assert ledr(2 downto 0) = "100"
            report "mode led is not set alarm" severity error;
        assert hex4 = SEG_0 and hex5 = SEG_0
            report "alarm hours are not shown as 00" severity error;

        -- alarm minutes to 01
        press(2);  -- field seconds -> minutes
        press(3);  -- alarm minutes = 1
        wait for 1 ns;
        assert hex2 = SEG_1
            report "alarm minutes did not set to 01" severity error;

        -- alarm hours to 12
        press(2);  -- field minutes -> hours
        for i in 1 to 12 loop
            press(3);
        end loop;
        wait for 1 ns;
        assert hex5 = SEG_1 and hex4 = SEG_2
            report "alarm hours did not set to 12" severity error;

        ----------------------------------------------------------------
        -- back to display, wait for the alarm to fire at 12 01 00
        ----------------------------------------------------------------
        press(1);  -- set alarm -> display
        wait for 1 ns;
        assert ledr(2 downto 0) = "001"
            report "mode did not return to display" severity error;

        wait until ledr(9) = '1' for 100 us;
        assert ledr(9) = '1'
            report "alarm did not fire" severity error;

        -- the notification must persist, the led keeps flashing
        wait until ledr(9) = '0' for 2 us;
        wait until ledr(9) = '1' for 2 us;
        assert ledr(9) = '1'
            report "alarm led is not flashing" severity error;

        ----------------------------------------------------------------
        -- soft reset clears the alarm but not the time
        ----------------------------------------------------------------
        held := hex4;
        sw(8) <= '1';
        for i in 1 to 5 loop wait until rising_edge(clk); end loop;
        wait for 1 ns;
        assert ledr(9) = '0' and ledr(8) = '0'
            report "soft reset did not clear the alarm" severity error;
        assert hex4 = held
            report "soft reset disturbed the time" severity error;
        sw(8) <= '0';

        ----------------------------------------------------------------
        -- hard reset returns the whole system to its initial state
        ----------------------------------------------------------------
        press(0);
        wait for 1 ns;
        assert hex5 = SEG_1 and hex4 = SEG_2 and hex0 = SEG_0
            report "hard reset did not restore 12 00 00" severity error;
        assert ledr(2 downto 0) = "001"
            report "hard reset did not restore display mode" severity error;

        report "testalarmclock finished, all checks passed";
        done <= true;
        wait;
    end process;

end architecture Behavioral;
