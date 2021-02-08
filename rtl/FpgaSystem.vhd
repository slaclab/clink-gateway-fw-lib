-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: System Level Modules
-------------------------------------------------------------------------------
-- This file is part of 'Camera link gateway'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'Camera link gateway', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.I2cPkg.all;

library clink_gateway_fw_lib;

library unisim;
use unisim.vcomponents.all;

entity FpgaSystem is
   generic (
      TPD_G           : time             := 1 ns;
      SIMULATION_G    : boolean          := false;
      BUILD_INFO_G    : BuildInfoType;
      AXI_CLK_FREQ_G  : real             := 125.0E+6;  -- units of Hz
      AXI_BASE_ADDR_G : slv(31 downto 0) := (others => '0'));
   port (
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in    sl;
      axilRst         : in    sl;
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType;
      -- SEM AXIS Interface (axilClk domain)
      semTxAxisMaster : out   AxiStreamMasterType;
      semTxAxisSlave  : in    AxiStreamSlaveType;
      semRxAxisMaster : in    AxiStreamMasterType;
      semRxAxisSlave  : out   AxiStreamSlaveType;
      -- Stable Reference SEM Clock and Reset
      semClk100MHz    : in    sl;
      semRst100MHz    : in    sl;
      -- Boot Memory Ports
      bootCsL         : out   sl;
      bootMosi        : out   sl;
      bootMiso        : in    sl;
      -- SFP Ports
      sfpScl          : inout slv(3 downto 0);
      sfpSda          : inout slv(3 downto 0);
      -- Misc Ports
      pwrScl          : inout sl;
      pwrSda          : inout sl;
      fdSerSdio       : inout sl;
      tempAlertL      : in    sl;
      vPIn            : in    sl;
      vNIn            : in    sl);
end FpgaSystem;

architecture mapping of FpgaSystem is

   constant NUM_AXIL_MASTERS_C : natural := 9;

   constant VERSION_INDEX_C  : natural := 0;
   constant BOOT_MEM_INDEX_C : natural := 1;
   constant PWR_INDEX_C      : natural := 2;
   constant XADC_INDEX_C     : natural := 3;
   constant SFP_INDEX_C      : natural := 4;  -- [4:7]
   constant SEM_INDEX_C      : natural := 8;

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXI_BASE_ADDR_G, 16, 12);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_OK_C);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_OK_C);

   constant PWR_I2C_C : I2cAxiLiteDevArray(1 downto 0) := (
      0              => MakeI2cAxiLiteDevType(
         i2cAddress  => "1001000",      -- 0x90 = SA56004ATK
         dataSize    => 8,              -- in units of bits
         addrSize    => 8,              -- in units of bits
         endianness  => '0',            -- Little endian
         repeatStart => '0'),           -- No repeat start
      1              => MakeI2cAxiLiteDevType(
         i2cAddress  => "1101111",      -- 0xDE = LTC4151CMS#PBF
         dataSize    => 8,              -- in units of bits
         addrSize    => 8,              -- in units of bits
         endianness  => '0',            -- Little endian
         repeatStart => '1'));          -- Repeat Start

   signal bootSck    : sl;
   signal userValues : Slv32Array(0 to 63) := (others => X"00000000");

   signal fpgaReload     : sl;
   signal fpgaReloadAddr : slv(31 downto 0);

begin

   --------------------------
   -- AXI-Lite: Crossbar Core
   --------------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   ---------------------------
   -- AXI-Lite: Version Module
   ---------------------------
   U_AxiVersion : entity surf.AxiVersion
      generic map (
         TPD_G           => TPD_G,
         BUILD_INFO_G    => BUILD_INFO_G,
         CLK_PERIOD_G    => (1.0/AXI_CLK_FREQ_G),
         XIL_DEVICE_G    => "7SERIES",
         EN_DEVICE_DNA_G => true,
         EN_ICAP_G       => false)   -- Located in the SEM
      port map (
         -- AXI-Lite Register Interface
         axiClk         => axilClk,
         axiRst         => axilRst,
         fdSerSdio      => fdSerSdio,
         userValues     => userValues,
         fpgaReload     => fpgaReload,
         fpgaReloadAddr => fpgaReloadAddr,
         axiReadMaster  => axilReadMasters(VERSION_INDEX_C),
         axiReadSlave   => axilReadSlaves(VERSION_INDEX_C),
         axiWriteMaster => axilWriteMasters(VERSION_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(VERSION_INDEX_C));

   NOT_SIM : if (SIMULATION_G = false) generate

      ------------------------------
      -- AXI-Lite: Boot Flash Module
      ------------------------------
      U_BootProm : entity surf.AxiMicronN25QCore
         generic map (
            TPD_G          => TPD_G,
            AXI_CLK_FREQ_G => AXI_CLK_FREQ_G,        -- units of Hz
            SPI_CLK_FREQ_G => (AXI_CLK_FREQ_G/8.0))  -- units of Hz
         port map (
            -- FLASH Memory Ports
            csL            => bootCsL,
            sck            => bootSck,
            mosi           => bootMosi,
            miso           => bootMiso,
            -- AXI-Lite Register Interface
            axiReadMaster  => axilReadMasters(BOOT_MEM_INDEX_C),
            axiReadSlave   => axilReadSlaves(BOOT_MEM_INDEX_C),
            axiWriteMaster => axilWriteMasters(BOOT_MEM_INDEX_C),
            axiWriteSlave  => axilWriteSlaves(BOOT_MEM_INDEX_C),
            -- Clocks and Resets
            axiClk         => axilClk,
            axiRst         => axilRst);

      -----------------------------------------------------
      -- Using the STARTUPE2 to access the FPGA's CCLK port
      -----------------------------------------------------
      STARTUPE2_Inst : STARTUPE2
         port map (
            CFGCLK    => open,  -- 1-bit output: Configuration main clock output
            CFGMCLK   => open,  -- 1-bit output: Configuration internal oscillator clock output
            EOS       => open,  -- 1-bit output: Active high output signal indicating the End Of Startup.
            PREQ      => open,  -- 1-bit output: PROGRAM request to fabric output
            CLK       => '0',  -- 1-bit input: User start-up clock input
            GSR       => '0',  -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
            GTS       => '0',  -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
            KEYCLEARB => '0',  -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
            PACK      => '0',  -- 1-bit input: PROGRAM acknowledge input
            USRCCLKO  => bootSck,       -- 1-bit input: User CCLK input
            USRCCLKTS => '0',  -- 1-bit input: User CCLK 3-state enable input
            USRDONEO  => '1',  -- 1-bit input: User DONE pin output control
            USRDONETS => '1');  -- 1-bit input: User DONE 3-state enable output

      ----------------------
      -- AXI-Lite: Power I2C
      ----------------------
      U_PwrI2C : entity surf.AxiI2cRegMaster
         generic map (
            TPD_G          => TPD_G,
            DEVICE_MAP_G   => PWR_I2C_C,
            I2C_SCL_FREQ_G => 400.0E+3,  -- units of Hz
            AXI_CLK_FREQ_G => AXI_CLK_FREQ_G)
         port map (
            -- I2C Ports
            scl            => pwrScl,
            sda            => pwrSda,
            -- AXI-Lite Register Interface
            axiReadMaster  => axilReadMasters(PWR_INDEX_C),
            axiReadSlave   => axilReadSlaves(PWR_INDEX_C),
            axiWriteMaster => axilWriteMasters(PWR_INDEX_C),
            axiWriteSlave  => axilWriteSlaves(PWR_INDEX_C),
            -- Clocks and Resets
            axiClk         => axilClk,
            axiRst         => axilRst);

      -----------------------
      -- AXI-Lite XADC Module
      -----------------------
      U_Xadc : entity surf.AxiXadcMinimumCore
         port map (
            -- XADC Ports
            vPIn           => vPIn,
            vNIn           => vNIn,
            -- AXI-Lite Register Interface
            axiReadMaster  => axilReadMasters(XADC_INDEX_C),
            axiReadSlave   => axilReadSlaves(XADC_INDEX_C),
            axiWriteMaster => axilWriteMasters(XADC_INDEX_C),
            axiWriteSlave  => axilWriteSlaves(XADC_INDEX_C),
            -- Clocks and Resets
            axiClk         => axilClk,
            axiRst         => axilRst);

      --------------------
      -- AXI-Lite: SFP I2C
      --------------------
      GEN_VEC : for i in 3 downto 0 generate
         U_SfpI2C : entity surf.Sff8472
            generic map (
               TPD_G          => TPD_G,
               I2C_SCL_FREQ_G => 400.0E+3,  -- units of Hz
               AXI_CLK_FREQ_G => AXI_CLK_FREQ_G)
            port map (
               -- I2C Ports
               scl             => sfpScl(i),
               sda             => sfpSda(i),
               -- AXI-Lite Register Interface
               axilReadMaster  => axilReadMasters(SFP_INDEX_C+i),
               axilReadSlave   => axilReadSlaves(SFP_INDEX_C+i),
               axilWriteMaster => axilWriteMasters(SFP_INDEX_C+i),
               axilWriteSlave  => axilWriteSlaves(SFP_INDEX_C+i),
               -- Clocks and Resets
               axilClk         => axilClk,
               axilRst         => axilRst);
      end generate GEN_VEC;

      U_SEM : entity clink_gateway_fw_lib.FebSemWrapper
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Stable Reference SEM Clock and Reset
            semClk          => semClk100MHz,
            semClkRst       => semRst100MHz,
            -- AXI-Lite Interface (axilClk domain)
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMasters(SEM_INDEX_C),
            axilReadSlave   => axilReadSlaves(SEM_INDEX_C),
            axilWriteMaster => axilWriteMasters(SEM_INDEX_C),
            axilWriteSlave  => axilWriteSlaves(SEM_INDEX_C),
            -- IPROG Interface (axilClk domain)
            fpgaReload      => fpgaReload,
            fpgaReloadAddr  => fpgaReloadAddr,
            -- SEM AXIS Interface (axisClk domain)
            axisClk         => axilClk,
            axisRst         => axilRst,
            semTxAxisMaster => semTxAxisMaster,
            semTxAxisSlave  => semTxAxisSlave,
            semRxAxisMaster => semRxAxisMaster,
            semRxAxisSlave  => semRxAxisSlave);

   end generate;

end mapping;
