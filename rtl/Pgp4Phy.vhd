-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for PGPv4 communication
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
use surf.Pgp4Pkg.all;

library unisim;
use unisim.vcomponents.all;

library clink_gateway_fw_lib;

entity Pgp4Phy is
   generic (
      TPD_G           : time    := 1 ns;
      SIMULATION_G    : boolean := false;
      AXI_CLK_FREQ_G  : real    := 125.0E+6;  -- units of Hz
      PHY_BASE_ADDR_G : slv(31 downto 0));
   port (
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : out sl;
      axilRst         : out sl;
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType;
      -- PHY AXI-Lite Interface (axilClk domain)
      phyReadMaster   : in  AxiLiteReadMasterType;
      phyReadSlave    : out AxiLiteReadSlaveType;
      phyWriteMaster  : in  AxiLiteWriteMasterType;
      phyWriteSlave   : out AxiLiteWriteSlaveType;
      -- Camera Data Interface (axilClk domain)
      dataMaster      : in  AxiStreamMasterType;
      dataSlave       : out AxiStreamSlaveType;
      -- UART Interface (axilClk domain)
      txUartMaster    : in  AxiStreamMasterType;
      txUartSlave     : out AxiStreamSlaveType;
      rxUartMaster    : out AxiStreamMasterType;
      rxUartSlave     : in  AxiStreamSlaveType;
      -- SEM AXIS Interface (axilClk domain)
      semTxAxisMaster : in  AxiStreamMasterType;
      semTxAxisSlave  : out AxiStreamSlaveType;
      semRxAxisMaster : out AxiStreamMasterType;
      semRxAxisSlave  : in  AxiStreamSlaveType;
      -- Trigger (axilClk domain)
      pgpTrigger      : out slv(1 downto 0);
      -- Stable Reference IDELAY Clock and Reset
      refClk200MHz    : out sl;
      refRst200MHz    : out sl;
      -- PGP Ports
      pgpClkP         : in  sl;
      pgpClkN         : in  sl;
      pgpRxP          : in  sl;
      pgpRxN          : in  sl;
      pgpTxP          : out sl;
      pgpTxN          : out sl);
end Pgp4Phy;

architecture mapping of Pgp4Phy is

   constant TX_CELL_WORDS_MAX_C : positive := 128;

   signal pgpRxIn  : Pgp4RxInArray(0 downto 0)  := (others => PGP4_RX_IN_INIT_C);
   signal pgpRxOut : Pgp4RxOutArray(0 downto 0) := (others => PGP4_RX_OUT_INIT_C);

   signal pgpTxIn  : Pgp4TxInArray(0 downto 0)  := (others => PGP4_TX_IN_INIT_C);
   signal pgpTxOut : Pgp4TxOutArray(0 downto 0) := (others => PGP4_TX_OUT_INIT_C);

   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpRxSlaves  : AxiStreamSlaveArray(3 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);

   signal pgpClk : slv(0 downto 0);
   signal pgpRst : slv(0 downto 0);

   signal pgpRefClkDiv2    : sl;
   signal pgpRefClkDiv2Rst : sl;

   signal sysClk : sl;
   signal sysRst : sl;

begin

   axilClk <= sysClk;
   axilRst <= sysRst;

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
         NUM_CLOCKS_G       => 2,
         -- MMCM attributes
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => 6.4,     -- 156.25 MHz
         CLKFBOUT_MULT_F_G  => 8.00,    -- VCO = 1250MHz
         CLKOUT0_DIVIDE_F_G => 6.25,    -- 200 MHz = 1250MHz/6.25
         CLKOUT1_DIVIDE_G   => 10)      -- 125 MHz = 1250MHz/10
      port map(
         clkIn     => pgpRefClkDiv2,
         rstIn     => pgpRefClkDiv2Rst,
         clkOut(0) => refClk200MHz,
         clkOut(1) => sysClk,
         rstOut(0) => refRst200MHz,
         rstOut(1) => sysRst);

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
         EN_GT_DRP_G          => false,
         EN_QPLL_DRP_G        => false,
         AXIL_BASE_ADDR_G     => PHY_BASE_ADDR_G,
         AXIL_CLK_FREQ_G      => AXI_CLK_FREQ_G)
      port map (
         -- Stable Clock and Reset
         stableClk         => sysClk,
         stableRst         => sysRst,
         -- Gt Serial IO
         pgpGtTxP(0)       => pgpTxP,
         pgpGtTxN(0)       => pgpTxN,
         pgpGtRxP(0)       => pgpRxP,
         pgpGtRxN(0)       => pgpRxN,
         -- GT Clocking
         pgpRefClkP        => pgpClkP,
         pgpRefClkN        => pgpClkN,
         pgpRefClkDiv2Bufg => pgpRefClkDiv2,
         -- Clocking
         pgpClk            => pgpClk,
         pgpClkRst         => pgpRst,
         -- Non VC Rx Signals
         pgpRxIn           => pgpRxIn,
         pgpRxOut          => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn           => pgpTxIn,
         pgpTxOut          => pgpTxOut,
         -- Frame Transmit Interface
         pgpTxMasters      => pgpTxMasters,
         pgpTxSlaves       => pgpTxSlaves,
         -- Frame Receive Interface
         pgpRxMasters      => pgpRxMasters,
         pgpRxCtrl         => pgpRxCtrl,
         pgpRxSlaves       => pgpRxSlaves,
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk           => sysClk,
         axilRst           => sysRst,
         axilReadMaster    => phyReadMaster,
         axilReadSlave     => phyReadSlave,
         axilWriteMaster   => phyWriteMaster,
         axilWriteSlave    => phyWriteSlave);

   U_SyncTrig : entity surf.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => sysClk,
         dataIn  => pgpRxOut(0).opCodeEn,
         dataOut => pgpTrigger(0));

   pgpTrigger(1) <= '0';

   U_PgpVcWrapper : entity clink_gateway_fw_lib.PgpVcWrapper
      generic map (
         TPD_G               => TPD_G,
         SIMULATION_G        => SIMULATION_G,
         GEN_SYNC_FIFO_G     => false,
         TX_CELL_WORDS_MAX_G => TX_CELL_WORDS_MAX_C,
         PHY_AXI_CONFIG_G    => PGP4_AXIS_CONFIG_C)
      port map (
         -- Clocks and Resets
         sysClk          => sysClk,
         sysRst          => sysRst,
         pgpTxClk        => pgpClk(0),
         pgpTxRst        => pgpRst(0),
         pgpRxClk        => pgpClk(0),
         pgpRxRst        => pgpRst(0),
         -- AXI-Lite Interface (sysClk domain)
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- Camera Data Interface (sysClk domain)
         dataMaster      => dataMaster,
         dataSlave       => dataSlave,
         -- UART Interface (sysClk domain)
         txUartMaster    => txUartMaster,
         txUartSlave     => txUartSlave,
         rxUartMaster    => rxUartMaster,
         rxUartSlave     => rxUartSlave,
         -- SEM AXIS Interface (sysClk domain)
         semTxAxisMaster => semTxAxisMaster,
         semTxAxisSlave  => semTxAxisSlave,
         semRxAxisMaster => semRxAxisMaster,
         semRxAxisSlave  => semRxAxisSlave,
         -- Frame TX Interface (pgpTxClk domain)
         pgpTxMasters    => pgpTxMasters,
         pgpTxSlaves     => pgpTxSlaves,
         -- Frame RX Interface (pgpRxClk domain)
         pgpRxMasters    => pgpRxMasters,
         pgpRxCtrl       => pgpRxCtrl,
         pgpRxSlaves     => pgpRxSlaves);

end mapping;
