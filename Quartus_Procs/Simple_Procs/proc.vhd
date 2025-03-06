library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity processor is
    generic(
        MV_OPCODE  : std_logic_vector(2 downto 0) := "000";
        MVI_OPCODE : std_logic_vector(2 downto 0) := "001";
        ADD_OPCODE : std_logic_vector(2 downto 0) := "010";
        SUB_OPCODE : std_logic_vector(2 downto 0) := "011"
    );
    
    port(
        clock   : in std_logic;
        aResetn : in std_logic;
        Run     : in std_logic;
        Din     : in std_logic_vector(8 downto 0);
        BusWires : buffer std_logic_vector(8 downto 0);
        Done    : buffer std_logic
    );
end processor;

architecture arch of processor is
    
    component dec3to8 is
        port(
            input  : in std_logic_vector(2 downto 0);
            enable : in std_logic;
            output : out std_logic_vector(7 downto 0)
        );
    end component;
    
    component reg_n is
        generic(N : integer := 9);
        port(
            clock  : in std_logic;
            enable : in std_logic;
            D      : in std_logic_vector(N-1 downto 0);
            Q      : out std_logic_vector(N-1 downto 0)
        );
    end component;
    
    type state_type is (T0, T1, T2, T3);
    signal Tcycle_D, Tcycle_Q : state_type;
    signal Rin, Rout, Xregn, Yregn : std_logic_vector(7 downto 0);
    signal DinOut, Gout, Ain, Gin, IRin, AddSub : std_logic;
    signal R0, R1, R2, R3, R4, R5, R6, R7, IR, G, A : std_logic_vector(8 downto 0);
    signal I : std_logic_vector(2 downto 0);
    signal sel : std_logic_vector(9 downto 0);
    signal sum : std_logic_vector(8 downto 0);
    
begin
    I <= IR(8 downto 6);
    
    -- Decoder for register selection
    U1: dec3to8 port map (input => IR(5 downto 3), enable => '1', output => Xregn);
    U2: dec3to8 port map (input => IR(2 downto 0), enable => '1', output => Yregn);
    
    -- State machine process
    fsm_next_state: process(Tcycle_Q, Run, Done)
    begin
        case Tcycle_Q is
            when T0 =>
                if Run = '0' then 
                    Tcycle_D <= T0;
                else 
                    Tcycle_D <= T1; 
                end if;
                
            when T1 =>
                if Done = '1' then 
                    Tcycle_D <= T0;
                else 
                    Tcycle_D <= T2; 
                end if;
                
            when T2 =>
                Tcycle_D <= T3;
            
            when T3 =>
                Tcycle_D <= T0;
        end case;
    end process fsm_next_state;
    
    control_signals: process(Tcycle_Q, I)
    begin
        -- Default signal values to 0 latches
        DinOut <= '0';
        Rout <= (others => '0');
        Gout <= '0';
        Ain <= '0';
        Gin <= '0';
        IRin <= '0';
        AddSub <= '0';
        Done <= '0';
        
        case Tcycle_Q is
            when T0 => 
                -- No control signals active in T0 state
                null;
            
            when T1 => 
                case I is
                    when MV_OPCODE =>
                        Rout <= Yregn; 
                        Rin <= Xregn; 
                        Done <= '1';
                    when MVI_OPCODE =>
                        DinOut <= '1'; 
                        Rin <= Xregn; 
                        Done <= '1';
                    when ADD_OPCODE =>
                        Rout <= Xregn; 
                        Ain <= '1';
                    when SUB_OPCODE =>
                        Rout <= Xregn; 
                        Ain <= '1'; 
                        AddSub <= '1';
                    when others =>
                        null;
                end case;
            
            when T2 => 
                case I is
                    when ADD_OPCODE | SUB_OPCODE =>
                        Rout <= Yregn; 
                        Gin <= '1';
                    when others =>
                        null;
                end case;
            
            when T3 => 
                case I is
                    when ADD_OPCODE | SUB_OPCODE =>
                        Gout <= '1'; 
                        Rin <= Xregn; 
                        Done <= '1';
                    when others =>
                        null;
                end case;
        end case;
    end process control_signals;
    
    -- State register update
    fsm_state_reg: process(clock, aResetn)
    begin
        if aResetn = '0' then
            Tcycle_Q <= T0;
        elsif rising_edge(clock) then
            Tcycle_Q <= Tcycle_D;
        end if;
    end process fsm_state_reg;
    
    -- Adder/Subtractor
    adder_subtractor: process(A, BusWires, AddSub)
    begin
        if AddSub = '0' then
            sum <= std_logic_vector(unsigned(A) + unsigned(BusWires));
        else
            sum <= std_logic_vector(unsigned(A) - unsigned(BusWires));
        end if;
    end process adder_subtractor;
    
    -- Bus mux selector
    sel <= DinOut & Rout & Gout;
    
    bus_mux: process(sel, Din, R0, R1, R2, R3, R4, R5, R6, R7, G)
    begin
        -- Default value to prevent latches
        BusWires <= (others => '0');
        
        case sel is
            when "1000000000" => BusWires <= Din;
            when "0100000000" => BusWires <= R0;
            when "0010000000" => BusWires <= R1;
            when "0001000000" => BusWires <= R2;
            when "0000100000" => BusWires <= R3;
            when "0000010000" => BusWires <= R4;
            when "0000001000" => BusWires <= R5;
            when "0000000100" => BusWires <= R6;
            when "0000000010" => BusWires <= R7;
            when "0000000001" => BusWires <= G;
            when others => BusWires <= (others => '0');
        end case;
    end process bus_mux;
    
    -- Register instantiations
    R0_reg: reg_n port map (clock => clock, enable => Rin(0), D => BusWires, Q => R0);
    R1_reg: reg_n port map (clock => clock, enable => Rin(1), D => BusWires, Q => R1);
    R2_reg: reg_n port map (clock => clock, enable => Rin(2), D => BusWires, Q => R2);
    R3_reg: reg_n port map (clock => clock, enable => Rin(3), D => BusWires, Q => R3);
    R4_reg: reg_n port map (clock => clock, enable => Rin(4), D => BusWires, Q => R4);
    R5_reg: reg_n port map (clock => clock, enable => Rin(5), D => BusWires, Q => R5);
    R6_reg: reg_n port map (clock => clock, enable => Rin(6), D => BusWires, Q => R6);
    R7_reg: reg_n port map (clock => clock, enable => Rin(7), D => BusWires, Q => R7);
    IR_reg: reg_n port map (clock => clock, enable => IRin, D => BusWires, Q => IR);
    G_reg: reg_n port map (clock => clock, enable => Gin, D => sum, Q => G);
    A_reg: reg_n port map (clock => clock, enable => Ain, D => BusWires, Q => A);
    
end arch;

library ieee;
use ieee.std_logic_1164.all;

entity dec3to8 is
    port(
        input  : in std_logic_vector(2 downto 0);
        enable : in std_logic;
        output : out std_logic_vector(7 downto 0)
    );
end dec3to8;

architecture arch of dec3to8 is
begin
    decoder_process: process(input, enable)
    begin
        -- Default value to 0 latches
        output <= (others => '0');
        
        if enable = '1' then
            case input is
                when "000"  => output <= "00000001";
                when "001"  => output <= "00000010";
                when "010"  => output <= "00000100";
                when "011"  => output <= "00001000";
                when "100"  => output <= "00010000";
                when "101"  => output <= "00100000";
                when "110"  => output <= "01000000";
                when "111"  => output <= "10000000";
                when others => output <= (others => '0');
            end case;
        end if;
    end process decoder_process;
end arch;

library ieee;
use ieee.std_logic_1164.all;

entity reg_n is
    generic(N : integer := 9);
    port(
        clock  : in std_logic;
        enable : in std_logic;
        D      : in std_logic_vector(N-1 downto 0);
        Q      : out std_logic_vector(N-1 downto 0)
    );
end reg_n;    

architecture arch of reg_n is
begin
    reg_process: process(clock)
    begin
        if rising_edge(clock) then
            if enable = '1' then
                Q <= D;
            end if;
        end if;
    end process reg_process;
end arch;