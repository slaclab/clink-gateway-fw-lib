-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: CameraLink Gateway Core
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;

library clink_gateway_fw_lib;

library unisim;
use unisim.vcomponents.all;

entity CLinkGateway is
   generic (
      TPD_G        : time    := 1 ns;
      BUILD_INFO_G : BuildInfoType;
      SIMULATION_G : boolean := false);
   port (
      -- Clink Ports
      cbl0Half0P    : inout slv(4 downto 0);  --  2,  4,  5,  6, 3
      cbl0Half0M    : inout slv(4 downto 0);  -- 15, 17, 18, 19 16
      cbl0Half1P    : inout slv(4 downto 0);  --  8, 10, 11, 12,  9
      cbl0Half1M    : inout slv(4 downto 0);  -- 21, 23, 24, 25, 22
      cbl0SerP      : out   sl;               -- 20
      cbl0SerM      : out   sl;               -- 7
      cbl1Half0P    : inout slv(4 downto 0);  --  2,  4,  5,  6, 3
      cbl1Half0M    : inout slv(4 downto 0);  -- 15, 17, 18, 19 16
      cbl1Half1P    : inout slv(4 downto 0);  --  8, 10, 11, 12,  9
      cbl1Half1M    : inout slv(4 downto 0);  -- 21, 23, 24, 25, 22
      cbl1SerP      : out   sl;               -- 20
      cbl1SerM      : out   sl;               -- 7
      -- LEDs
      ledRed        : out   slv(1 downto 0);
      ledGrn        : out   slv(1 downto 0);
      ledBlu        : out   slv(1 downto 0);
      -- Boot Memory Ports
      bootCsL       : out   sl;
      bootMosi      : out   sl;
      bootMiso      : in    sl;
      -- Timing GPIO Ports
      timingClkSel  : out   sl;
      timingXbarSel : out   slv(3 downto 0);
      -- GTX Ports
      gtClkP        : in    slv(1 downto 0);
      gtClkN        : in    slv(1 downto 0);
      gtRxP         : in    slv(3 downto 0);
      gtRxN         : in    slv(3 downto 0);
      gtTxP         : out   slv(3 downto 0);
      gtTxN         : out   slv(3 downto 0);
      -- SFP Ports
      sfpScl        : inout slv(3 downto 0);
      sfpSda        : inout slv(3 downto 0);
      -- Misc Ports
      pwrScl        : inout sl;
      pwrSda        : inout sl;
      configScl     : inout sl;
      configSda     : inout sl;
      fdSerSdio     : inout sl;
      tempAlertL    : in    sl;
      vPIn          : in    sl;
      vNIn          : in    sl);
end CLinkGateway;

architecture mapping of CLinkGateway is

   constant AXIL_CLK_FREQ_C : real := 104.167E+6;  -- units of Hz

   constant NUM_AXIL_MASTERS_C : natural := 5;

   constant SYS_INDEX_C    : natural := 0;
   constant CLINK_INDEX_C  : natural := 1;
   constant TIMING_INDEX_C : natural := 2;
   constant PROM_INDEX_C   : natural := 3;
   constant PGP_INDEX_C    : natural := 4;

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, x"00000000", 24, 20);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C);

   signal axilClk           : sl;
   signal axilRst           : sl;
   signal mAxilReadMasters  : AxiLiteReadMasterArray(1 downto 0);
   signal mAxilReadSlaves   : AxiLiteReadSlaveArray(1 downto 0);
   signal mAxilWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray(1 downto 0);

   signal refClk200MHz : sl;
   signal refRst200MHz : sl;

   signal dataMaster : AxiStreamMasterType;
   signal dataSlave  : AxiStreamSlaveType;

   signal txUartMaster : AxiStreamMasterType;
   signal txUartSlave  : AxiStreamSlaveType;
   signal rxUartMaster : AxiStreamMasterType;
   signal rxUartSlave  : AxiStreamSlaveType;

   signal pgpTrigger : slv(1 downto 0);
   signal camCtrl    : Slv4Array(1 downto 0);

   signal semTxAxisMaster : AxiStreamMasterType;
   signal semTxAxisSlave  : AxiStreamSlaveType;
   signal semRxAxisMaster : AxiStreamMasterType;
   signal semRxAxisSlave  : AxiStreamSlaveType;

   signal semClk100MHz : sl;
   signal semRst100MHz : sl;

   signal gtClk     : sl;
   signal gtClkDiv2 : sl;

   signal clinkUp     : sl;
   signal pgp2bLinkUp : sl;
   signal pgp4LinkUp  : sl;

begin

   -- Bottom LED: CLINK Status
   ledRed(0) <= clinkUp;
   ledGrn(0) <= not(clinkUp);
   ledBlu(0) <= '1';

   -- Top LED: PGP LINK Status
   ledRed(1) <= '1';
   ledGrn(1) <= not(pgp2bLinkUp);
   ledBlu(1) <= not(pgp4LinkUp);

   ----------
   -- PGP PHY
   ----------
   U_PGP : entity clink_gateway_fw_lib.PgpPhy
      generic map (
         TPD_G           => TPD_G,
         SIMULATION_G    => SIMULATION_G,
         AXI_CLK_FREQ_G  => AXIL_CLK_FREQ_C,
         PHY_BASE_ADDR_G => XBAR_CONFIG_C(PGP_INDEX_C).baseAddr)
      port map (
         -- AXI-Lite Interface (axilClk domain)
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMasters  => mAxilReadMasters,
         axilReadSlaves   => mAxilReadSlaves,
         axilWriteMasters => mAxilWriteMasters,
         axilWriteSlaves  => mAxilWriteSlaves,
         -- PHY AXI-Lite Interface (axilClk domain)
         phyReadMaster    => axilReadMasters(PGP_INDEX_C),
         phyReadSlave     => axilReadSlaves(PGP_INDEX_C),
         phyWriteMaster   => axilWriteMasters(PGP_INDEX_C),
         phyWriteSlave    => axilWriteSlaves(PGP_INDEX_C),
         -- Camera Data Interface
         dataMaster       => dataMaster,
         dataSlave        => dataSlave,
         -- UART Interface
         txUartMaster     => txUartMaster,
         txUartSlave      => txUartSlave,
         rxUartMaster     => rxUartMaster,
         rxUartSlave      => rxUartSlave,
         -- SEM AXIS Interface (axilClk domain)
         semTxAxisMaster  => semTxAxisMaster,
         semTxAxisSlave   => semTxAxisSlave,
         semRxAxisMaster  => semRxAxisMaster,
         semRxAxisSlave   => semRxAxisSlave,
         -- Trigger and Link Status
         pgpTrigger       => pgpTrigger(0),
         -- Stable Reference IDELAY Clock and Reset
         refClk200MHz     => refClk200MHz,
         refRst200MHz     => refRst200MHz,
         -- PGP Ports
         pgp2bLinkUp      => pgp2bLinkUp,
         pgp4LinkUp       => pgp4LinkUp,
         pgpClkP          => gtClkP(0),
         pgpClkN          => gtClkN(0),
         pgpRxP           => gtRxP(1 downto 0),
         pgpRxN           => gtRxN(1 downto 0),
         pgpTxP           => gtTxP(1 downto 0),
         pgpTxN           => gtTxN(1 downto 0));

   --------------------------
   -- AXI-Lite: Crossbar Core
   --------------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk           => axilClk,
         axiClkRst        => axilRst,
         sAxiWriteMasters => mAxilWriteMasters,
         sAxiWriteSlaves  => mAxilWriteSlaves,
         sAxiReadMasters  => mAxilReadMasters,
         sAxiReadSlaves   => mAxilReadSlaves,
         mAxiWriteMasters => axilWriteMasters,
         mAxiWriteSlaves  => axilWriteSlaves,
         mAxiReadMasters  => axilReadMasters,
         mAxiReadSlaves   => axilReadSlaves);

   -----------------
   -- System Modules
   -----------------
   U_FpgaSystem : entity clink_gateway_fw_lib.FpgaSystem
      generic map (
         TPD_G           => TPD_G,
         SIMULATION_G    => SIMULATION_G,
         BUILD_INFO_G    => BUILD_INFO_G,
         AXI_CLK_FREQ_G  => AXIL_CLK_FREQ_C,
         AXI_BASE_ADDR_G => XBAR_CONFIG_C(SYS_INDEX_C).baseAddr)
      port map (
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(SYS_INDEX_C),
         axilReadSlave   => axilReadSlaves(SYS_INDEX_C),
         axilWriteMaster => axilWriteMasters(SYS_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(SYS_INDEX_C),
         -- SEM AXIS Interface (axilClk domain)
         semTxAxisMaster => semTxAxisMaster,
         semTxAxisSlave  => semTxAxisSlave,
         semRxAxisMaster => semRxAxisMaster,
         semRxAxisSlave  => semRxAxisSlave,
         -- Stable Reference SEM Clock and Reset
         semClk100MHz    => semClk100MHz,
         semRst100MHz    => semRst100MHz,
         -- Boot Memory Ports
         bootCsL         => bootCsL,
         bootMosi        => bootMosi,
         bootMiso        => bootMiso,
         -- SFP Ports
         sfpScl          => sfpScl,
         sfpSda          => sfpSda,
         -- Misc Ports
         pwrScl          => pwrScl,
         pwrSda          => pwrSda,
         fdSerSdio       => fdSerSdio,
         tempAlertL      => tempAlertL,
         vPIn            => vPIn,
         vNIn            => vNIn);

   ----------------
   -- CLink Wrapper
   ----------------
   U_CLinkWrapper : entity clink_gateway_fw_lib.CLinkWrapper
      generic map (
         TPD_G            => TPD_G,
         AXIL_BASE_ADDR_G => XBAR_CONFIG_C(CLINK_INDEX_C).baseAddr)
      port map (
         -- Clink Ports
         cbl0Half0P      => cbl0Half0P,
         cbl0Half0M      => cbl0Half0M,
         cbl0Half1P      => cbl0Half1P,
         cbl0Half1M      => cbl0Half1M,
         cbl0SerP        => cbl0SerP,
         cbl0SerM        => cbl0SerM,
         cbl1Half0P      => cbl1Half0P,
         cbl1Half0M      => cbl1Half0M,
         cbl1Half1P      => cbl1Half1P,
         cbl1Half1M      => cbl1Half1M,
         cbl1SerP        => cbl1SerP,
         cbl1SerM        => cbl1SerM,
         -- CLINK Status
         clinkUp         => clinkUp,
         -- Stable Reference IDELAY Clock and Reset
         refClk200MHz    => refClk200MHz,
         refRst200MHz    => refRst200MHz,
         -- Camera Control Bits
         camCtrl         => camCtrl(0),
         -- Camera Data Interface
         dataMaster      => dataMaster,
         dataSlave       => dataSlave,
         -- UART Interface
         txUartMaster    => txUartMaster,
         txUartSlave     => txUartSlave,
         rxUartMaster    => rxUartMaster,
         rxUartSlave     => rxUartSlave,
         -- Axi-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(CLINK_INDEX_C),
         axilReadSlave   => axilReadSlaves(CLINK_INDEX_C),
         axilWriteMaster => axilWriteMasters(CLINK_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(CLINK_INDEX_C));

   -----------------
   -- Trigger Module
   -----------------
   U_Trig : entity clink_gateway_fw_lib.TriggerTop
      generic map (
         TPD_G           => TPD_G,
         SIMULATION_G    => SIMULATION_G,
         AXIL_CLK_FREQ_G => AXIL_CLK_FREQ_C,
         AXI_BASE_ADDR_G => XBAR_CONFIG_C(TIMING_INDEX_C).baseAddr)
      port map (
         -- Trigger Input
         pgpTrigger      => pgpTrigger,
         camCtrl         => camCtrl,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(TIMING_INDEX_C),
         axilReadSlave   => axilReadSlaves(TIMING_INDEX_C),
         axilWriteMaster => axilWriteMasters(TIMING_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(TIMING_INDEX_C));

   ----------------------------
   -- Terminate MISC Interfaces
   ----------------------------
   timingClkSel  <= '0';
   timingXbarSel <= x"0";

   U_IBUFDS_GTE2 : IBUFDS_GTE2
      port map (
         I     => gtClkP(1),
         IB    => gtClkN(1),
         CEB   => '0',
         ODIV2 => gtClkDiv2,
         O     => gtClk);

   U_TerminateGtx : entity surf.Gtxe2ChannelDummy
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map (
         refClk => gtClkDiv2,
         gtRxP  => gtRxP(3 downto 2),
         gtRxN  => gtRxN(3 downto 2),
         gtTxP  => gtTxP(3 downto 2),
         gtTxN  => gtTxN(3 downto 2));

   ----------------------
   -- SEM Clock and Reset
   ----------------------
   U_semClk100MHz : BUFR
      generic map (
         BUFR_DIVIDE => "2")
      port map (
         CE  => '1',
         CLR => '0',
         I   => refClk200MHz,
         O   => semClk100MHz);

   U_semRst100MHz : entity surf.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => semClk100MHz,
         asyncRst => refRst200MHz,
         syncRst  => semRst100MHz);

end mapping;
