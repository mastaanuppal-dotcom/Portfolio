-- Mastaan Uppal, Eugene Magsino

library ieee;
use ieee.std_logic_1164.all;

-- drives a bouncing input into the debouncer and checks that the output
-- ignores the bounces and only follows the input once it is stable
-- a small count_max is used so the simulation stays short
entity TestDebounce is
end entity TestDebounce;

architecture Behavioral of TestDebounce is

    component Debounce is
        generic ( COUNT_MAX : integer := 500000 );
        port ( clk, rst, din : in std_logic; dout : out std_logic );
    end component;

    signal clk  : std_logic := '0';
    signal rst  : std_logic := '1';
    signal din  : std_logic := '0';
    signal dout : std_logic;

    signal done : boolean := false;

begin

    dut : Debounce
        generic map ( COUNT_MAX => 4 )
        port map ( clk => clk, rst => rst, din => din, dout => dout );

    clk_gen : process
    begin
        while not done loop
            clk <= '0'; wait for 10 ns;
            clk <= '1'; wait for 10 ns;
        end loop;
        wait;
    end process;

    stimulus : process
    begin
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        -- simulated contact bounce, short pulses that must be ignored
        for i in 1 to 4 loop
            din <= '1';
            wait until rising_edge(clk);
            din <= '0';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            assert dout = '0'
                report "debouncer passed a bounce through" severity error;
        end loop;

        -- now a real press, stable high
        din <= '1';

        -- output must still be low before the stable interval has elapsed
        for i in 1 to 4 loop
            wait until rising_edge(clk);
        end loop;
        assert dout = '0'
            report "debouncer switched too early" severity error;

        -- after the full debounce interval the output must be high
        for i in 1 to 6 loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;
        assert dout = '1'
            report "debouncer did not accept a stable press" severity error;

        -- release with bounces, output must stay high through them
        for i in 1 to 3 loop
            din <= '0';
            wait until rising_edge(clk);
            din <= '1';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            assert dout = '1'
                report "debouncer dropped out during release bounce" severity error;
        end loop;

        -- stable release
        din <= '0';
        for i in 1 to 10 loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;
        assert dout = '0'
            report "debouncer did not accept a stable release" severity error;

        report "testdebounce finished, all checks passed";
        done <= true;
        wait;
    end process;

end architecture Behavioral;
