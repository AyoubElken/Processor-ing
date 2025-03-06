library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipelined_processor is
    generic(
        MV_OPCODE   : std_logic_vector(3 downto 0) := "0000";
        MVI_OPCODE  : std_logic_vector(3 downto 0) := "0001";
        ADD_OPCODE  : std_logic_vector(3 downto 0) := "0010";
        SUB_OPCODE  : std_logic_vector(3 downto 0) := "0011";
        MUL_OPCODE  : std_logic_vector(3 downto 0) := "0100";
        AND_OPCODE  : std_logic_vector(3 downto 0) := "0110";
        OR_OPCODE   : std_logic_vector(3 downto 0) := "0111";
        XOR_OPCODE  : std_logic_vector(3 downto 0) := "1000";
        SHL_OPCODE  : std_logic_vector(3 downto 0) := "1001";
        SHR_OPCODE  : std_logic_vector(3 downto 0) := "1010";
        LD_OPCODE   : std_logic_vector(3 downto 0) := "1011";
        ST_OPCODE   : std_logic_vector(3 downto 0) := "1100";
        JMP_OPCODE  : std_logic_vector(3 downto 0) := "1101";
        BEQ_OPCODE  : std_logic_vector(3 downto 0) := "1110";
        HALT_OPCODE : std_logic_vector(3 downto 0) := "1111"
    );
    port(
        clock      : in  std_logic;
        reset_n    : in  std_logic;
        start      : in  std_logic;
        data_in    : in  std_logic_vector(15 downto 0);
        addr_in    : in  std_logic_vector(15 downto 0);
        data_out   : out std_logic_vector(15 downto 0);
        addr_out   : out std_logic_vector(15 downto 0);
        mem_read   : out std_logic;
        mem_write  : out std_logic;
        done       : out std_logic
    );
end pipelined_processor;

architecture rtl of pipelined_processor is
    -- ALU operation cst
    constant ALU_ADD : std_logic_vector(3 downto 0) := "0000";
    constant ALU_SUB : std_logic_vector(3 downto 0) := "0001";
    constant ALU_MUL : std_logic_vector(3 downto 0) := "0010";
    constant ALU_AND : std_logic_vector(3 downto 0) := "0011";
    constant ALU_OR  : std_logic_vector(3 downto 0) := "0100";
    constant ALU_XOR : std_logic_vector(3 downto 0) := "0101";
    constant ALU_SHL : std_logic_vector(3 downto 0) := "0110";
    constant ALU_SHR : std_logic_vector(3 downto 0) := "0111";
    constant ALU_PASS: std_logic_vector(3 downto 0) := "1000";

    -- Pipeline regs
    signal IF_ID_IR, IF_ID_PC     : std_logic_vector(15 downto 0);
    signal ID_EX_IR, ID_EX_PC     : std_logic_vector(15 downto 0);
    signal EX_MEM_IR, EX_MEM_ALU_res : std_logic_vector(15 downto 0);
    signal MEM_WB_IR, MEM_WB_data : std_logic_vector(15 downto 0);

    -- Control sigs
    signal pc_select, pc_write, stall, flush : std_logic;
    signal reg_write_en, halt_flag           : std_logic;

    -- Register file
    type register_array is array(0 to 7) of std_logic_vector(15 downto 0);
    signal registers : register_array;

    -- ALU sigs
    signal alu_op    : std_logic_vector(3 downto 0);
    signal alu_a, alu_b, alu_result : std_logic_vector(15 downto 0);
    signal alu_zero, alu_ovf : std_logic;

begin
    -- ALU instance with explicit operation mapping
    alu_inst: entity work.alu(rtl)
        port map(
            A        => alu_a,
            B        => alu_b,
            op       => alu_op,
            result   => alu_result,
            zero     => alu_zero,
            overflow => alu_ovf
        );

    -- Pipeline control process
    control_unit: process(EX_MEM_IR, alu_zero, stall)
    begin
        -- Default control sigs
        pc_select <= '0';
        flush <= '0';
        pc_write <= not stall;

        -- Branch/Jump handling
        if EX_MEM_IR(15 downto 12) = JMP_OPCODE then
            pc_select <= '1';
            flush <= '1';
        elsif EX_MEM_IR(15 downto 12) = BEQ_OPCODE and alu_zero = '1' then
            pc_select <= '1';
            flush <= '1';
        end if;
    end process;

    -- Fetch stage with stall handling
    fetch_stage: process(clock, reset_n)
    begin
        if reset_n = '0' then
            IF_ID_IR <= (others => '0');
            IF_ID_PC <= (others => '0');
        elsif rising_edge(clock) and stall = '0' then
            IF_ID_IR <= data_in;  -- Assume data_in provides instructs
            IF_ID_PC <= addr_in;  -- Use addr_in for PC
        end if;
    end process;

    -- Decode
    decode_stage: process(clock)
        variable imm : std_logic_vector(15 downto 0);
    begin
        if rising_edge(clock) and stall = '0' then
            -- Sign-extend lower 9 bits for I-type instructs
            imm(15 downto 9) := (others => IF_ID_IR(8));
            imm(8 downto 0)  := IF_ID_IR(8 downto 0);
            
            ID_EX_IR <= IF_ID_IR;
            ID_EX_PC <= IF_ID_PC;
            
            -- Reg read with hazard protection
            alu_a <= registers(to_integer(unsigned(IF_ID_IR(11 downto 9))));
            alu_b <= registers(to_integer(unsigned(IF_ID_IR(8 downto 6))));
        end if;
    end process;

    -- Execute stage with ALU ops mapping
    execute_stage: process(clock)
    begin
        if rising_edge(clock) then
            case ID_EX_IR(15 downto 12) is
                when ADD_OPCODE  => alu_op <= ALU_ADD;
                when SUB_OPCODE  => alu_op <= ALU_SUB;
                when MUL_OPCODE  => alu_op <= ALU_MUL;
                when AND_OPCODE  => alu_op <= ALU_AND;
                when OR_OPCODE   => alu_op <= ALU_OR;
                when XOR_OPCODE  => alu_op <= ALU_XOR;
                when SHL_OPCODE  => alu_op <= ALU_SHL;
                when SHR_OPCODE  => alu_op <= ALU_SHR;
                when others      => alu_op <= ALU_PASS;
            end case;

            EX_MEM_ALU_res <= alu_result;
            EX_MEM_IR <= ID_EX_IR;
        end if;
    end process;

    -- Memory stage
    memory_stage: process(clock)
    begin
        if rising_edge(clock) then
            mem_read <= '0';
            mem_write <= '0';
            
            case EX_MEM_IR(15 downto 12) is
                when LD_OPCODE =>
                    addr_out <= EX_MEM_ALU_res;
                    mem_read <= '1';
                    MEM_WB_data <= data_in;
                when ST_OPCODE =>
                    addr_out <= EX_MEM_ALU_res;
                    data_out <= registers(to_integer(unsigned(EX_MEM_IR(5 downto 3))));
                    mem_write <= '1';
                when others =>
                    MEM_WB_data <= EX_MEM_ALU_res;
            end case;
            
            MEM_WB_IR <= EX_MEM_IR;
        end if;
    end process;

    -- Writeback stage register writeback
    writeback_stage: process(clock)
    begin
        if rising_edge(clock) then
            reg_write_en <= '0';
            done <= '0';
            
            if MEM_WB_IR(15 downto 12) = HALT_OPCODE then
                done <= '1';
                halt_flag <= '1';
            elsif MEM_WB_IR(15 downto 12) /= ST_OPCODE then
                registers(to_integer(unsigned(MEM_WB_IR(11 downto 9)))) <= MEM_WB_data;
                reg_write_en <= '1';
            end if;
        end if;
    end process;

end rtl;

-- ALU Component
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    port(
        A       : in std_logic_vector(15 downto 0);
        B       : in std_logic_vector(15 downto 0);
        op      : in std_logic_vector(3 downto 0);
        result  : out std_logic_vector(15 downto 0);
        zero    : out std_logic;
        overflow: out std_logic
    );
end alu;

architecture rtl of alu is
    signal temp_result : std_logic_vector(15 downto 0);
    signal temp_zero : std_logic;
    signal temp_overflow : std_logic;
    signal mul_result : std_logic_vector(31 downto 0);
begin
    process(A, B, op)
    begin
        temp_overflow <= '0';
        
        case op is
            when "0000" =>  -- ADD
                temp_result <= std_logic_vector(unsigned(A) + unsigned(B));
                -- Check for overflow (simplified)
                if (A(15) = '0' and B(15) = '0' and temp_result(15) = '1') or
                   (A(15) = '1' and B(15) = '1' and temp_result(15) = '0') then
                    temp_overflow <= '1';
                end if;
                
            when "0001" =>  -- SUB
                temp_result <= std_logic_vector(unsigned(A) - unsigned(B));
                -- Check for overflow (simplified)
                if (A(15) = '0' and B(15) = '1' and temp_result(15) = '1') or
                   (A(15) = '1' and B(15) = '0' and temp_result(15) = '0') then
                    temp_overflow <= '1';
                end if;
                
            when "0010" =>  -- MUL
                mul_result <= std_logic_vector(unsigned(A) * unsigned(B));
                temp_result <= mul_result(15 downto 0);
                -- Overflow if upper bits are non-zero
                if mul_result(31 downto 16) /= x"0000" then
                    temp_overflow <= '1';
                end if;
                
            when "0011" =>  -- AND
                temp_result <= A and B;
                
            when "0100" =>  -- OR
                temp_result <= A or B;
                
            when "0101" =>  -- XOR
                temp_result <= A xor B;
                
            when "0110" =>  -- SHL
                temp_result <= std_logic_vector(shift_left(unsigned(A), to_integer(unsigned(B(3 downto 0)))));
                
            when "0111" =>  -- SHR
                temp_result <= std_logic_vector(shift_right(unsigned(A), to_integer(unsigned(B(3 downto 0)))));
                
            when "1000" =>  -- PASS THROUGH A
                temp_result <= A;
                
            when "1001" =>  -- PASS THROUGH B
                temp_result <= B;
                
            when others =>
                temp_result <= (others => '0');
        end case;
        
        -- Check for 0 result
        if temp_result = x"0000" then
            temp_zero <= '1';
        else
            temp_zero <= '0';
        end if;
    end process;
    
    result <= temp_result;
    zero <= temp_zero;
    overflow <= temp_overflow;
end rtl;

-- Register Component with Reset
library ieee;
use ieee.std_logic_1164.all;

entity reg_n is
    generic(N : integer := 16);
    port(
        clock  : in std_logic;
        reset_n: in std_logic;
        enable : in std_logic;
        D      : in std_logic_vector(N-1 downto 0);
        Q      : out std_logic_vector(N-1 downto 0)
    );
end reg_n;    

architecture rtl of reg_n is
begin
    process(clock, reset_n)
    begin
        if reset_n = '0' then
            Q <= (others => '0');
        elsif rising_edge(clock) then
            if enable = '1' then
                Q <= D;
            end if;
        end if;
    end process;
end rtl;

-- Decoder Component (3-to-8)
library ieee;
use ieee.std_logic_1164.all;

entity dec3to8 is
    port(
        input  : in std_logic_vector(2 downto 0);
        enable : in std_logic;
        output : out std_logic_vector(7 downto 0)
    );
end dec3to8;

architecture rtl of dec3to8 is
begin
    process(input, enable)
    begin
        -- Default val
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
    end process;
end rtl;

