-- Mastaan Uppal, Eugene Magsino

library ieee;
use ieee.std_logic_1164.all;

-- top level digital alarm clock for the de10 standard board
--
-- controls
--   key0 hard reset, resets time to 12 00 00 and alarm to 00 00 00
--   key1 cycle mode, display time -> set time -> set alarm
--   key2 cycle edit field, seconds -> minutes -> hours
--   key3 increment the selected field
--   sw8  alarm stop, soft reset that clears an active alarm only
--   sw9  fast demo mode, time runs 100 times faster
--
-- outputs
--   hex5 hex4 hours, hex3 hex2 minutes, hex1 hex0 seconds
--   ledr0 ledr1 ledr2 one hot mode indicator
--   ledr3 ledr4 ledr5 one hot edit field indicator in the set modes
--   ledr8 ledr9 flash while the alarm is active
entity AlarmClock is
    generic (
        DEB_MAX    : integer := 500000;    -- debounce interval, 10 ms
        DIV_NORMAL : integer := 50000000;  -- clock cycles per second
        DIV_FAST   : integer := 500000;    -- demo speed up division
        DIV_BLINK  : integer := 6250000    -- alarm flash toggle rate
    );
    port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(3 downto 0);
        SW       : in  std_logic_vector(9 downto 0);
        LEDR     : out std_logic_vector(9 downto 0);
        HEX0     : out std_logic_vector(6 downto 0);
        HEX1     : out std_logic_vector(6 downto 0);
        HEX2     : out std_logic_vector(6 downto 0);
        HEX3     : out std_logic_vector(6 downto 0);
        HEX4     : out std_logic_vector(6 downto 0);
        HEX5     : out std_logic_vector(6 downto 0)
    );
end entity AlarmClock;

architecture Structural of AlarmClock is

    component Debounce is
        generic ( COUNT_MAX : integer := 500000 );
        port ( clk, rst, din : in std_logic; dout : out std_logic );
    end component;

    component EdgeDetect is
        port ( clk, rst, din : in std_logic; pulse : out std_logic );
    end component;

    component PreScale is
        generic ( DIV_NORMAL : integer := 50000000;
                  DIV_FAST   : integer := 500000;
                  DIV_BLINK  : integer := 6250000 );
        port ( clk, rst, fast : in std_logic;
               tick_sec, blink : out std_logic );
    end component;

    component BCDCounter is
        generic ( MOD_MAX : integer := 60; INIT : integer := 0 );
        port ( clk, rst, en : in std_logic;
               tens, ones : out std_logic_vector(3 downto 0);
               rollover : out std_logic );
    end component;

    component ClockFSM is
        port ( clk, rst, mode_key, field_key : in std_logic;
               mode, field : out std_logic_vector(2 downto 0) );
    end component;

    component AlarmControl is
        port ( clk, rst, match, stop, blink : in std_logic;
               alarm_on, alarm_led : out std_logic );
    end component;

    component SegDecoder is
        port ( D : in std_logic_vector(3 downto 0);
               Y : out std_logic_vector(6 downto 0) );
    end component;

    -- reset and debounced buttons, keys on the board are active low
    signal rst_raw, rst : std_logic;
    signal key1_db, key2_db, key3_db : std_logic;
    signal mode_pulse, field_pulse, inc_pulse : std_logic;

    -- timing
    signal tick_sec, blink : std_logic;

    -- fsm outputs, one hot
    signal mode, field : std_logic_vector(2 downto 0);
    signal in_set_time, in_set_alarm : std_logic;

    -- current time digits
    signal sec_t, sec_o, min_t, min_o, hr_t, hr_o : std_logic_vector(3 downto 0);
    signal sec_roll, min_roll, hr_roll : std_logic;
    signal sec_en, min_en, hr_en : std_logic;

    -- alarm time digits
    signal asec_t, asec_o, amin_t, amin_o, ahr_t, ahr_o : std_logic_vector(3 downto 0);
    signal asec_en, amin_en, ahr_en : std_logic;
    signal aroll0, aroll1, aroll2 : std_logic;

    -- alarm logic
    signal match, alarm_on, alarm_led : std_logic;

    -- digits routed to the displays
    signal d0, d1, d2, d3, d4, d5 : std_logic_vector(3 downto 0);

begin

    ------------------------------------------------------------------
    -- input conditioning
    ------------------------------------------------------------------

    rst_raw <= not KEY(0);

    -- debounce the reset so releasing the key does not glitch the system
    u_deb0 : Debounce
        generic map ( COUNT_MAX => DEB_MAX )
        port map ( clk => CLOCK_50, rst => '0', din => rst_raw, dout => rst );

    u_deb1 : Debounce
        generic map ( COUNT_MAX => DEB_MAX )
        port map ( clk => CLOCK_50, rst => rst, din => not KEY(1), dout => key1_db );

    u_deb2 : Debounce
        generic map ( COUNT_MAX => DEB_MAX )
        port map ( clk => CLOCK_50, rst => rst, din => not KEY(2), dout => key2_db );

    u_deb3 : Debounce
        generic map ( COUNT_MAX => DEB_MAX )
        port map ( clk => CLOCK_50, rst => rst, din => not KEY(3), dout => key3_db );

    u_edge1 : EdgeDetect
        port map ( clk => CLOCK_50, rst => rst, din => key1_db, pulse => mode_pulse );

    u_edge2 : EdgeDetect
        port map ( clk => CLOCK_50, rst => rst, din => key2_db, pulse => field_pulse );

    u_edge3 : EdgeDetect
        port map ( clk => CLOCK_50, rst => rst, din => key3_db, pulse => inc_pulse );

    ------------------------------------------------------------------
    -- timing and control
    ------------------------------------------------------------------

    u_prescale : PreScale
        generic map ( DIV_NORMAL => DIV_NORMAL,
                      DIV_FAST   => DIV_FAST,
                      DIV_BLINK  => DIV_BLINK )
        port map ( clk => CLOCK_50, rst => rst, fast => SW(9),
                   tick_sec => tick_sec, blink => blink );

    u_fsm : ClockFSM
        port map ( clk => CLOCK_50, rst => rst,
                   mode_key => mode_pulse, field_key => field_pulse,
                   mode => mode, field => field );

    in_set_time  <= mode(1);
    in_set_alarm <= mode(2);

    ------------------------------------------------------------------
    -- current time counters
    -- timekeeping pauses while the time is being edited
    -- carries are blocked in set time mode so editing one field
    -- never disturbs the others
    ------------------------------------------------------------------

    sec_en <= (tick_sec and (not in_set_time)) or
              (inc_pulse and in_set_time and field(0));
    min_en <= (sec_roll and (not in_set_time)) or
              (inc_pulse and in_set_time and field(1));
    hr_en  <= (min_roll and (not in_set_time)) or
              (inc_pulse and in_set_time and field(2));

    u_sec : BCDCounter
        generic map ( MOD_MAX => 60, INIT => 0 )
        port map ( clk => CLOCK_50, rst => rst, en => sec_en,
                   tens => sec_t, ones => sec_o, rollover => sec_roll );

    u_min : BCDCounter
        generic map ( MOD_MAX => 60, INIT => 0 )
        port map ( clk => CLOCK_50, rst => rst, en => min_en,
                   tens => min_t, ones => min_o, rollover => min_roll );

    u_hr : BCDCounter
        generic map ( MOD_MAX => 24, INIT => 12 )
        port map ( clk => CLOCK_50, rst => rst, en => hr_en,
                   tens => hr_t, ones => hr_o, rollover => hr_roll );

    ------------------------------------------------------------------
    -- alarm time counters, only change in set alarm mode
    ------------------------------------------------------------------

    asec_en <= inc_pulse and in_set_alarm and field(0);
    amin_en <= inc_pulse and in_set_alarm and field(1);
    ahr_en  <= inc_pulse and in_set_alarm and field(2);

    u_asec : BCDCounter
        generic map ( MOD_MAX => 60, INIT => 0 )
        port map ( clk => CLOCK_50, rst => rst, en => asec_en,
                   tens => asec_t, ones => asec_o, rollover => aroll0 );

    u_amin : BCDCounter
        generic map ( MOD_MAX => 60, INIT => 0 )
        port map ( clk => CLOCK_50, rst => rst, en => amin_en,
                   tens => amin_t, ones => amin_o, rollover => aroll1 );

    u_ahr : BCDCounter
        generic map ( MOD_MAX => 24, INIT => 0 )
        port map ( clk => CLOCK_50, rst => rst, en => ahr_en,
                   tens => ahr_t, ones => ahr_o, rollover => aroll2 );

    ------------------------------------------------------------------
    -- alarm comparison and notification
    ------------------------------------------------------------------

    match <= '1' when (sec_t = asec_t) and (sec_o = asec_o) and
                      (min_t = amin_t) and (min_o = amin_o) and
                      (hr_t  = ahr_t)  and (hr_o  = ahr_o) else '0';

    u_alarm : AlarmControl
        port map ( clk => CLOCK_50, rst => rst,
                   match => match, stop => SW(8), blink => blink,
                   alarm_on => alarm_on, alarm_led => alarm_led );

    ------------------------------------------------------------------
    -- display, the alarm time is shown while it is being set
    ------------------------------------------------------------------

    d0 <= asec_o when in_set_alarm = '1' else sec_o;
    d1 <= asec_t when in_set_alarm = '1' else sec_t;
    d2 <= amin_o when in_set_alarm = '1' else min_o;
    d3 <= amin_t when in_set_alarm = '1' else min_t;
    d4 <= ahr_o  when in_set_alarm = '1' else hr_o;
    d5 <= ahr_t  when in_set_alarm = '1' else hr_t;

    u_hex0 : SegDecoder port map ( D => d0, Y => HEX0 );
    u_hex1 : SegDecoder port map ( D => d1, Y => HEX1 );
    u_hex2 : SegDecoder port map ( D => d2, Y => HEX2 );
    u_hex3 : SegDecoder port map ( D => d3, Y => HEX3 );
    u_hex4 : SegDecoder port map ( D => d4, Y => HEX4 );
    u_hex5 : SegDecoder port map ( D => d5, Y => HEX5 );

    ------------------------------------------------------------------
    -- led indicators
    ------------------------------------------------------------------

    LEDR(2 downto 0) <= mode;
    LEDR(5 downto 3) <= field when (in_set_time = '1' or in_set_alarm = '1')
                        else "000";
    LEDR(7 downto 6) <= "00";
    LEDR(8) <= alarm_led;
    LEDR(9) <= alarm_led;

end architecture Structural;
