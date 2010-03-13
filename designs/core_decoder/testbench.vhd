----------------------------------------------------------------------------------------------
--
--      Input file         : config_Pkg.vhd
--      Design name        : config_Pkg
--      Author             : Tamar Kranenburg
--      Company            : Delft University of Technology
--                         : Faculty EEMCS, Department ME&CE
--                         : Systems and Circuits group
--
--      Description        : Testbench which instantiates instruction memory, data memory,
--                           core, core address decoder and stdio
--
----------------------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;

LIBRARY mblite;
USE mblite.config_Pkg.ALL;
USE mblite.core_Pkg.ALL;
USE mblite.std_Pkg.ALL;

ENTITY testbench IS
END testbench;

ARCHITECTURE arch OF testbench IS

    COMPONENT mblite_stdio IS PORT
    (
        dmem_i : OUT dmem_in_type;
        dmem_o : IN dmem_out_type;
        clk_i  : IN std_logic
    );
    END COMPONENT;

    SIGNAL dmem_o : dmem_out_type;
    SIGNAL dmem_i : dmem_in_type;
    SIGNAL imem_o : imem_out_type;
    SIGNAL imem_i : imem_in_type;
    SIGNAL s_dmem_o : dmem_out_array_type(CFG_NUM_SLAVES - 1 DOWNTO 0);
    SIGNAL s_dmem_i : dmem_in_array_type(CFG_NUM_SLAVES - 1 DOWNTO 0);

    SIGNAL sys_clk_i : std_logic := '0';
    SIGNAL sys_int_i : std_logic;
    SIGNAL sys_rst_i : std_logic;

    CONSTANT rom_size : integer := 16;
    CONSTANT ram_size : integer := 16;

    SIGNAL sel_o : std_logic_vector(3 DOWNTO 0);
    SIGNAL ena_o : std_logic;

BEGIN

    sys_clk_i <= NOT sys_clk_i AFTER 10000 ps;
    sys_rst_i <= '1' AFTER 0 ps, '0' AFTER  150000 ps;
    sys_int_i <= '1' AFTER 500000000 ps, '0' after 500040000 ps;

    -- Warning: an infinite loop like while(1) {} triggers this timeout too!
    -- disable this feature when a premature finish occur.
    timeout: PROCESS(sys_clk_i)
    BEGIN
        IF NOW = 10 ms THEN
            REPORT "TIMEOUT" SEVERITY FAILURE;
        END IF;
        -- BREAK ON EXIT (0xB8000000)
        IF compare(imem_i.dat_i, "10111000000000000000000000000000") = '1' THEN
            -- Make sure the simulator finishes when an error is encountered.
            -- For modelsim: see menu Simulate -> Runtime options -> Assertions
            REPORT "FINISHED" SEVERITY FAILURE;
        END IF;
    END PROCESS;

    stdio : mblite_stdio PORT MAP
    (
        dmem_i => s_dmem_i(1),
        dmem_o => s_dmem_o(1),
        clk_i  => sys_clk_i
    );

    s_dmem_i(0).ena_i <= '1';
    sel_o <= s_dmem_o(0).sel_o WHEN s_dmem_o(0).we_o = '1' ELSE (OTHERS => '0');
    ena_o <= NOT sys_rst_i AND s_dmem_o(0).ena_o;

    dmem : sram_4en GENERIC MAP
    (
        WIDTH => CFG_DMEM_WIDTH,
        SIZE => ram_size - 2
    )
    PORT MAP
    (
        dat_o => s_dmem_i(0).dat_i,
        dat_i => s_dmem_o(0).dat_o,
        adr_i => s_dmem_o(0).adr_o(ram_size - 1 DOWNTO 2),
        wre_i => sel_o,
        ena_i => ena_o,
        clk_i => sys_clk_i
    );

    decoder : core_address_decoder GENERIC MAP
    (
        G_NUM_SLAVES => CFG_NUM_SLAVES
    )
    PORT MAP
    (
        m_dmem_i => dmem_i,
        s_dmem_o => s_dmem_o,
        m_dmem_o => dmem_o,
        s_dmem_i => s_dmem_i,
        clk_i    => sys_clk_i
    );

    imem : sram GENERIC MAP
    (
        WIDTH => CFG_IMEM_WIDTH,
        SIZE => rom_size - 2
    )
    PORT MAP
    (
        dat_o => imem_i.dat_i,
        dat_i => "00000000000000000000000000000000",
        adr_i => imem_o.adr_o(rom_size - 1 DOWNTO 2),
        wre_i => '0',
        ena_i => imem_o.ena_o,
        clk_i => sys_clk_i
    );

    core0 : core PORT MAP
    (
        imem_o => imem_o,
        dmem_o => dmem_o,
        imem_i => imem_i,
        dmem_i => dmem_i,
        int_i  => sys_int_i,
        rst_i  => sys_rst_i,
        clk_i  => sys_clk_i
    );

END arch;
