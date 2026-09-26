-- Mastaan Uppal

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- verifies the bcd counter wrap and carry behavior
-- checks a mod 60 counter starting at 0 and a mod 24 counter starting at 12
entity TestBCDCounter is
end entity TestBCDCounter;

architecture Behavioral of TestBCDCounter is

    component BCDCounter is
        generic ( MOD_MAX : integer := 60; INIT : integer := 0 );
        port ( clk, rst, en : in std_logic;
               tens, ones : out std_logic_vector(3 downto 0);
               rollover : out std_logic );
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal en  : std_logic := '0';

    signal s_tens, s_ones : std_logic_vector(3 downto 0);
    signal h_tens, h_ones : std_logic_vector(3 downto 0);
    signal s_roll, h_roll : std_logic;

    signal done : boolean := false;

begin

    u_sec : BCDCounter
        generic map ( MOD_MAX => 60, INIT => 0 )
        port map ( clk => clk, rst => rst, en => en,
                   tens => s_tens, ones => s_ones, rollover => s_roll );

    u_hr : BCDCounter
        generic map ( MOD_MAX => 24, INIT => 12 )
        port map ( clk => clk, rst => rst, en => en,
                   tens => h_tens, ones => h_ones, rollover => h_roll );

    -- 50 mhz clock
    clk_gen : process
    begin
        while not done loop
            clk <= '0'; wait for 10 ns;
            clk <= '1'; wait for 10 ns;
        end loop;
        wait;
    end process;

    stimulus : process
        variable exp_s, exp_h : integer;
    begin
        -- hold reset for two cycles then release
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';
        en  <= '1';
        wait for 1 ns;

        -- check reset values
        assert s_tens = "0000" and s_ones = "0000"
            report "seconds counter did not reset to 00" severity error;
        assert h_tens = "0001" and h_ones = "0010"
            report "hours counter did not reset to 12" severity error;

        -- count 130 pulses, enough to wrap the mod 60 counter twice
        -- and the mod 24 counter several times
        for i in 1 to 130 loop
            wait until rising_edge(clk);
            wait for 1 ns;

            exp_s := i mod 60;
            exp_h := (12 + i) mod 24;

            assert to_integer(unsigned(s_tens)) = exp_s / 10 and
                   to_integer(unsigned(s_ones)) = exp_s mod 10
                report "mod 60 counter wrong at pulse " & integer'image(i)
                severity error;

            assert to_integer(unsigned(h_tens)) = exp_h / 10 and
                   to_integer(unsigned(h_ones)) = exp_h mod 10
                report "mod 24 counter wrong at pulse " & integer'image(i)
                severity error;

            -- rollover must pulse exactly when the counter holds its maximum
            if exp_s = 59 then
                assert s_roll = '1'
                    report "mod 60 rollover missing at 59" severity error;
            else
                assert s_roll = '0'
                    report "mod 60 rollover unexpected" severity error;
            end if;

            if exp_h = 23 then
                assert h_roll = '1'
                    report "mod 24 rollover missing at 23" severity error;
            else
                assert h_roll = '0'
                    report "mod 24 rollover unexpected" severity error;
            end if;
        end loop;

        report "testbcdcounter finished, all checks passed";
        done <= true;
        wait;
    end process;

end architecture Behavioral;
