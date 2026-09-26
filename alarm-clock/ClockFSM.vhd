-- Mastaan Uppal

library ieee;
use ieee.std_logic_1164.all;

-- main control fsm using one hot state encoding
-- mode key cycles display time -> set time -> set alarm -> display time
-- field key cycles the field being edited seconds -> minutes -> hours -> seconds
-- any invalid state recovers safely to display time and the seconds field
entity ClockFSM is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        mode_key  : in  std_logic;  -- one cycle pulse from the mode button
        field_key : in  std_logic;  -- one cycle pulse from the field button
        mode      : out std_logic_vector(2 downto 0);  -- one hot mode
        field     : out std_logic_vector(2 downto 0)   -- one hot edit field
    );
end entity ClockFSM;

architecture Behavioral of ClockFSM is
    -- one hot mode encoding, exactly one bit high per state
    constant M_DISPLAY   : std_logic_vector(2 downto 0) := "001";
    constant M_SET_TIME  : std_logic_vector(2 downto 0) := "010";
    constant M_SET_ALARM : std_logic_vector(2 downto 0) := "100";

    -- one hot field encoding
    constant F_SEC : std_logic_vector(2 downto 0) := "001";
    constant F_MIN : std_logic_vector(2 downto 0) := "010";
    constant F_HR  : std_logic_vector(2 downto 0) := "100";

    signal mode_r  : std_logic_vector(2 downto 0) := M_DISPLAY;
    signal field_r : std_logic_vector(2 downto 0) := F_SEC;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                mode_r  <= M_DISPLAY;
                field_r <= F_SEC;
            elsif mode_key = '1' then
                -- advance to the next mode and start editing at the seconds field
                case mode_r is
                    when M_DISPLAY   => mode_r <= M_SET_TIME;
                    when M_SET_TIME  => mode_r <= M_SET_ALARM;
                    when M_SET_ALARM => mode_r <= M_DISPLAY;
                    when others      => mode_r <= M_DISPLAY;  -- safe recovery
                end case;
                field_r <= F_SEC;
            elsif field_key = '1' then
                case field_r is
                    when F_SEC  => field_r <= F_MIN;
                    when F_MIN  => field_r <= F_HR;
                    when F_HR   => field_r <= F_SEC;
                    when others => field_r <= F_SEC;  -- safe recovery
                end case;
            end if;
        end if;
    end process;

    mode  <= mode_r;
    field <= field_r;

end architecture Behavioral;
