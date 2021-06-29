-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for PGP communication
-------------------------------------------------------------------------------
-- This file is part of 'ATLAS ALTIROC DEV'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'ATLAS ALTIROC DEV', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp2bPkg.all;
use surf.Pgp4Pkg.all;

library unisim;
use unisim.vcomponents.all;

library clink_gateway_fw_lib;

entity PgpPhy is
   generic (
      TPD_G           : time    := 1 ns;
      SIMULATION_G    : boolean := false;
      AXI_CLK_FREQ_G  : real    := 125.0E+6;  -- units of Hz
      PHY_BASE_ADDR_G : slv(31 downto 0));
   port (
      -- AXI-Lite Interface (axilClk domain)
      axilClk          : out sl;
      axilRst          : out sl;
      axilReadMasters  : out AxiLiteReadMasterArray(1 downto 0);
      axilReadSlaves   : in  AxiLiteReadSlaveArray(1 downto 0);
      axilWriteMasters : out AxiLiteWriteMasterArray(1 downto 0);
      axilWriteSlaves  : in  AxiLiteWriteSlaveArray(1 downto 0);
      -- PHY AXI-Lite Interface (axilClk domain)
      phyReadMaster    : in  AxiLiteReadMasterType;
      phyReadSlave     : out AxiLiteReadSlaveType;
      phyWriteMaster   : in  AxiLiteWriteMasterType;
      phyWriteSlave    : out AxiLiteWriteSlaveType;
      -- Camera Data Interface (axilClk domain)
      dataMaster       : in  AxiStreamMasterType;
      dataSlave        : out AxiStreamSlaveType;
      -- UART Interface (axilClk domain)
      txUartMaster     : in  AxiStreamMasterType;
      txUartSlave      : out AxiStreamSlaveType;
      rxUartMaster     : out AxiStreamMasterType;
      rxUartSlave      : in  AxiStreamSlaveType;
      -- SEM AXIS Interface (axilClk domain)
      semTxAxisMaster  : in  AxiStreamMasterType;
      semTxAxisSlave   : out AxiStreamSlaveType;
      semRxAxisMaster  : out AxiStreamMasterType;
      semRxAxisSlave   : in  AxiStreamSlaveType;
      -- Trigger (axilClk domain)
      pgpTrigger       : out sl;
      -- Stable Reference IDELAY Clock and Reset
      refClk200MHz     : out sl;
      refRst200MHz     : out sl;
      -- PGP Ports
      pgpClkP          : in  sl;
      pgpClkN          : in  sl;
      pgp2bLinkUp      : out sl;
      pgp4LinkUp       : out sl;
      pgpRxP           : in  slv(1 downto 0);
      pgpRxN           : in  slv(1 downto 0);
      pgpTxP           : out slv(1 downto 0);
      pgpTxN           : out slv(1 downto 0));
end PgpPhy;

architecture mapping of PgpPhy is

   constant TX_CELL_WORDS_MAX_C : positive := 256;

   constant NUM_AXIL_MASTERS_C : natural := 2;

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, PHY_BASE_ADDR_G, 20, 16);

   signal phyReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal phyReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C);
   signal phyWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal phyWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C);

   signal pgp2bRxIn  : Pgp2bRxInType  := PGP2B_RX_IN_INIT_C;
   signal pgp2bRxOut : Pgp2bRxOutType := PGP2B_RX_OUT_INIT_C;
   signal pgp2bTxIn  : Pgp2bTxInType  := PGP2B_TX_IN_INIT_C;
   signal pgp2bTxOut : Pgp2bTxOutType := PGP2B_TX_OUT_INIT_C;

   signal pgp4RxIn  : Pgp4RxInType  := PGP4_RX_IN_INIT_C;
   signal pgp4RxOut : Pgp4RxOutType := PGP4_RX_OUT_INIT_C;
   signal pgp4TxIn  : Pgp4TxInType  := PGP4_TX_IN_INIT_C;
   signal pgp4TxOut : Pgp4TxOutType := PGP4_TX_OUT_INIT_C;

   signal pgpTxMasters : AxiStreamMasterArray(7 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpTxSlaves  : AxiStreamSlaveArray(7 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal pgpRxMasters : AxiStreamMasterArray(7 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpRxSlaves  : AxiStreamSlaveArray(7 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal pgpRxCtrl    : AxiStreamCtrlArray(7 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);

   signal pgpRxClk : slv(1 downto 0);
   signal pgpRxRst : slv(1 downto 0);

   signal pgpTxClk : slv(1 downto 0);
   signal pgpTxRst : slv(1 downto 0);

   signal pgpRefClk        : sl;
   signal pgpRefClkDiv2    : sl;
   signal pgpRefClkDiv2Rst : sl;

   signal sysClk : sl;
   signal sysRst : sl;

   signal pgpTriggers : slv(1 downto 0);
   signal rxlinkReady : slv(1 downto 0);
   signal txlinkReady : slv(1 downto 0);

begin

   axilClk <= sysClk;
   axilRst <= sysRst;

   pgpTrigger <= uOr(pgpTriggers);

   pgp2bLinkUp <= pgp2bRxOut.linkReady;
   pgp4LinkUp  <= pgp4RxOut.linkReady;

   U_SyncTrig0 : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => sysClk,
         dataIn  => pgp2bRxOut.opCodeEn,
         dataOut => pgpTriggers(0));

   U_SyncTrig1 : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => sysClk,
         dataIn  => pgp4RxOut.opCodeEn,
         dataOut => pgpTriggers(1));

   U_PwrUpRst : entity surf.PwrUpRst
      generic map(
         TPD_G         => TPD_G,
         SIM_SPEEDUP_G => SIMULATION_G)
      port map (
         clk    => pgpRefClkDiv2,
         rstOut => pgpRefClkDiv2Rst);

   U_MMCM : entity surf.ClockManager7
      generic map(
         TPD_G              => TPD_G,
         SIMULATION_G       => SIMULATION_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => false,
         RST_IN_POLARITY_G  => '1',
         NUM_CLOCKS_G       => 3,
         -- MMCM attributes
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => 6.4,     -- 156.25 MHz
         CLKFBOUT_MULT_F_G  => 8.00,    -- VCO = 1250MHz
         CLKOUT0_DIVIDE_F_G => 6.25,    -- 200 MHz = 1250MHz/6.25
         CLKOUT1_DIVIDE_G   => 10,      -- 125 MHz = 1250MHz/10
         CLKOUT2_DIVIDE_G   => 8)       -- 156.25 MHz = 1250MHz/8
      port map(
         clkIn     => pgpRefClkDiv2,
         rstIn     => pgpRefClkDiv2Rst,
         clkOut(0) => refClk200MHz,
         clkOut(1) => sysClk,
         clkOut(2) => pgpTxClk(0),
         rstOut(0) => refRst200MHz,
         rstOut(1) => sysRst,
         rstOut(2) => pgpTxRst(0));

   -- Using Variable Latency PGP2b
   pgpRxClk(0) <= pgpTxClk(0);
   pgpRxRst(0) <= pgpTxRst(0);

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => sysClk,
         axiClkRst           => sysRst,
         sAxiWriteMasters(0) => phyWriteMaster,
         sAxiWriteSlaves(0)  => phyWriteSlave,
         sAxiReadMasters(0)  => phyReadMaster,
         sAxiReadSlaves(0)   => phyReadSlave,
         mAxiWriteMasters    => phyWriteMasters,
         mAxiWriteSlaves     => phyWriteSlaves,
         mAxiReadMasters     => phyReadMasters,
         mAxiReadSlaves      => phyReadSlaves);

   U_PGP2b : entity surf.Pgp2bGtx7VarLat
      generic map (
         TPD_G             => TPD_G,
         -- CPLL Configurations
         TX_PLL_G          => "CPLL",
         RX_PLL_G          => "CPLL",
         CPLL_REFCLK_SEL_G => "001",
         CPLL_FBDIV_G      => 2,
         CPLL_FBDIV_45_G   => 5,
         CPLL_REFCLK_DIV_G => 1,
         -- MGT Configurations
         RXOUT_DIV_G       => 2,
         TXOUT_DIV_G       => 2,
         RX_CLK25_DIV_G    => 13,
         TX_CLK25_DIV_G    => 13,
         RXDFEXYDEN_G      => '1',
         RX_DFE_KL_CFG2_G  => x"301148AC",
         -- VC Configuration
         VC_INTERLEAVE_G   => 1)
      port map (
         -- GT Clocking
         stableClk        => pgpRefClkDiv2,
         gtCPllRefClk     => pgpRefClk,
         gtCPllLock       => open,
         gtQPllRefClk     => '0',
         gtQPllClk        => '0',
         gtQPllLock       => '1',
         gtQPllRefClkLost => '0',
         gtQPllReset      => open,
         -- GT Serial IO
         gtTxP            => pgpTxP(0),
         gtTxN            => pgpTxN(0),
         gtRxP            => pgpRxP(0),
         gtRxN            => pgpRxN(0),
         -- Tx Clocking
         pgpTxReset       => pgpTxRst(0),
         pgpTxRecClk      => open,
         pgpTxClk         => pgpTxClk(0),
         pgpTxMmcmReset   => open,
         pgpTxMmcmLocked  => '1',
         -- Rx clocking
         pgpRxReset       => pgpRxRst(0),
         pgpRxRecClk      => open,
         pgpRxClk         => pgpRxClk(0),
         pgpRxMmcmReset   => open,
         pgpRxMmcmLocked  => '1',
         -- Non VC TX Signals
         pgpTxIn          => pgp2bTxIn,
         pgpTxOut         => pgp2bTxOut,
         -- Non VC RX Signals
         pgpRxIn          => pgp2bRxIn,
         pgpRxOut         => pgp2bRxOut,
         -- Frame TX Interface
         pgpTxMasters     => pgpTxMasters(3 downto 0),
         pgpTxSlaves      => pgpTxSlaves(3 downto 0),
         -- Frame RX Interface
         pgpRxMasters     => pgpRxMasters(3 downto 0),
         pgpRxCtrl        => pgpRxCtrl(3 downto 0));

   U_Pgp2bMon : entity surf.Pgp2bAxi
      generic map (
         TPD_G              => TPD_G,
         COMMON_TX_CLK_G    => false,
         COMMON_RX_CLK_G    => false,
         WRITE_EN_G         => false,
         AXI_CLK_FREQ_G     => AXI_CLK_FREQ_G,
         STATUS_CNT_WIDTH_G => 8,
         ERROR_CNT_WIDTH_G  => 8)
      port map (
         -- TX PGP Interface (pgpTxClk)
         pgpTxClk        => pgpTxClk(0),
         pgpTxClkRst     => pgpTxRst(0),
         pgpTxIn         => pgp2bTxIn,
         pgpTxOut        => pgp2bTxOut,
         -- RX PGP Interface (pgpRxClk)
         pgpRxClk        => pgpRxClk(0),
         pgpRxClkRst     => pgpRxRst(0),
         pgpRxIn         => pgp2bRxIn,
         pgpRxOut        => pgp2bRxOut,
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk         => sysClk,
         axilRst         => sysRst,
         axilReadMaster  => phyReadMasters(0),
         axilReadSlave   => phyReadSlaves(0),
         axilWriteMaster => phyWriteMasters(0),
         axilWriteSlave  => phyWriteSlaves(0));

   U_PGPv4 : entity surf.Pgp4Gtx7Wrapper
      generic map(
         TPD_G                => TPD_G,
         ROGUE_SIM_EN_G       => SIMULATION_G,
         ROGUE_SIM_PORT_NUM_G => 8000,
         NUM_LANES_G          => 1,
         NUM_VC_G             => 4,
         RATE_G               => "6.25Gbps",
         REFCLK_FREQ_G        => 312.5E+6,
         TX_CELL_WORDS_MAX_G  => TX_CELL_WORDS_MAX_C,
         EN_PGP_MON_G         => true,
         WRITE_EN_G           => false,
         EN_GT_DRP_G          => false,
         EN_QPLL_DRP_G        => false,
         AXIL_BASE_ADDR_G     => XBAR_CONFIG_C(1).baseAddr,
         AXIL_CLK_FREQ_G      => AXI_CLK_FREQ_G)
      port map (
         -- Stable Clock and Reset
         stableClk         => sysClk,
         stableRst         => sysRst,
         -- Gt Serial IO
         pgpGtTxP(0)       => pgpTxP(1),
         pgpGtTxN(0)       => pgpTxN(1),
         pgpGtRxP(0)       => pgpRxP(1),
         pgpGtRxN(0)       => pgpRxN(1),
         -- GT Clocking
         pgpRefClkP        => pgpClkP,
         pgpRefClkN        => pgpClkN,
         pgpRefClkOut      => pgpRefClk,
         pgpRefClkDiv2Bufg => pgpRefClkDiv2,
         -- Clocking
         pgpClk(0)         => pgpTxClk(1),
         pgpClkRst(0)      => pgpTxRst(1),
         -- Non VC Rx Signals
         pgpRxIn(0)        => pgp4RxIn,
         pgpRxOut(0)       => pgp4RxOut,
         -- Non VC Tx Signals
         pgpTxIn(0)        => pgp4TxIn,
         pgpTxOut(0)       => pgp4TxOut,
         -- Frame Transmit Interface
         pgpTxMasters      => pgpTxMasters(7 downto 4),
         pgpTxSlaves       => pgpTxSlaves(7 downto 4),
         -- Frame Receive Interface
         pgpRxMasters      => pgpRxMasters(7 downto 4),
         pgpRxCtrl         => pgpRxCtrl(7 downto 4),
         pgpRxSlaves       => pgpRxSlaves(7 downto 4),
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk           => sysClk,
         axilRst           => sysRst,
         axilReadMaster    => phyReadMasters(1),
         axilReadSlave     => phyReadSlaves(1),
         axilWriteMaster   => phyWriteMasters(1),
         axilWriteSlave    => phyWriteSlaves(1));

   pgpRxClk(1) <= pgpTxClk(1);
   pgpRxRst(1) <= pgpTxRst(1);

   rxlinkReady(0) <= pgp2bRxOut.linkReady;
   txlinkReady(0) <= pgp2bTxOut.linkReady;

   rxlinkReady(1) <= pgp4RxOut.linkReady;
   txlinkReady(1) <= pgp4TxOut.linkReady;

   U_PgpVcWrapper : entity clink_gateway_fw_lib.PgpVcWrapper
      generic map (
         TPD_G               => TPD_G,
         SIMULATION_G        => SIMULATION_G,
         TX_CELL_WORDS_MAX_G => TX_CELL_WORDS_MAX_C)
      port map (
         -- Clocks and Resets
         sysClk           => sysClk,
         sysRst           => sysRst,
         pgpTxClk         => pgpTxClk,
         pgpTxRst         => pgpTxRst,
         pgpRxClk         => pgpRxClk,
         pgpRxRst         => pgpRxRst,
         rxlinkReady      => rxlinkReady,
         txlinkReady      => txlinkReady,
         -- AXI-Lite Interface (sysClk domain)
         axilReadMasters  => axilReadMasters,
         axilReadSlaves   => axilReadSlaves,
         axilWriteMasters => axilWriteMasters,
         axilWriteSlaves  => axilWriteSlaves,
         -- Camera Data Interface (sysClk domain)
         dataMaster       => dataMaster,
         dataSlave        => dataSlave,
         -- UART Interface (sysClk domain)
         txUartMaster     => txUartMaster,
         txUartSlave      => txUartSlave,
         rxUartMaster     => rxUartMaster,
         rxUartSlave      => rxUartSlave,
         -- SEM AXIS Interface (sysClk domain)
         semTxAxisMaster  => semTxAxisMaster,
         semTxAxisSlave   => semTxAxisSlave,
         semRxAxisMaster  => semRxAxisMaster,
         semRxAxisSlave   => semRxAxisSlave,
         -- Frame TX Interface (pgpTxClk domain)
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         -- Frame RX Interface (pgpRxClk domain)
         pgpRxMasters     => pgpRxMasters,
         pgpRxCtrl        => pgpRxCtrl,
         pgpRxSlaves      => pgpRxSlaves);

end mapping;
