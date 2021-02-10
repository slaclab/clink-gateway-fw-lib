-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PGP Virtual Channel Mapping
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
use surf.Pgp2bPkg.all;
use surf.Pgp4Pkg.all;

entity PgpVcWrapper is
   generic (
      TPD_G               : time    := 1 ns;
      SIMULATION_G        : boolean := false;
      TX_CELL_WORDS_MAX_G : integer := 256);
   port (
      -- Clocks and Resets
      sysClk           : in  sl;
      sysRst           : in  sl;
      pgpTxClk         : in  slv(1 downto 0);
      pgpTxRst         : in  slv(1 downto 0);
      pgpRxClk         : in  slv(1 downto 0);
      pgpRxRst         : in  slv(1 downto 0);
      rxlinkReady      : in  slv(1 downto 0);
      txlinkReady      : in  slv(1 downto 0);
      -- AXI-Lite Interface (sysClk domain)
      axilReadMasters  : out AxiLiteReadMasterArray(1 downto 0);
      axilReadSlaves   : in  AxiLiteReadSlaveArray(1 downto 0);
      axilWriteMasters : out AxiLiteWriteMasterArray(1 downto 0);
      axilWriteSlaves  : in  AxiLiteWriteSlaveArray(1 downto 0);
      -- Camera Data Interface (sysClk domain)
      dataMaster       : in  AxiStreamMasterType;
      dataSlave        : out AxiStreamSlaveType;
      -- UART Interface (sysClk domain)
      txUartMaster     : in  AxiStreamMasterType;
      txUartSlave      : out AxiStreamSlaveType;
      rxUartMaster     : out AxiStreamMasterType;
      rxUartSlave      : in  AxiStreamSlaveType;
      -- SEM AXIS Interface (sysClk domain)
      semTxAxisMaster  : in  AxiStreamMasterType;
      semTxAxisSlave   : out AxiStreamSlaveType;
      semRxAxisMaster  : out AxiStreamMasterType;
      semRxAxisSlave   : in  AxiStreamSlaveType;
      -- Frame TX Interface (pgpTxClk domain)
      pgpTxMasters     : out AxiStreamMasterArray(7 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves      : in  AxiStreamSlaveArray(7 downto 0);
      -- Frame RX Interface (pgpRxClk domain)
      pgpRxMasters     : in  AxiStreamMasterArray(7 downto 0);
      pgpRxCtrl        : out AxiStreamCtrlArray(7 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);
      pgpRxSlaves      : out AxiStreamSlaveArray(7 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C));
end PgpVcWrapper;

architecture mapping of PgpVcWrapper is

   constant PHY_AXI_CONFIG_C : AxiStreamConfigArray(1 downto 0) := (0 => SSI_PGP2B_CONFIG_C, 1 => PGP4_AXIS_CONFIG_C);

   signal dataMasters : AxiStreamMasterArray(1 downto 0);
   signal dataSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal txUartMasters : AxiStreamMasterArray(1 downto 0);
   signal txUartSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal rxUartMasters : AxiStreamMasterArray(1 downto 0);
   signal rxUartSlaves  : AxiStreamSlaveArray(1 downto 0);

   signal semTxAxisMasters : AxiStreamMasterArray(1 downto 0);
   signal semTxAxisSlaves  : AxiStreamSlaveArray(1 downto 0);
   signal semRxAxisMasters : AxiStreamMasterArray(1 downto 0);
   signal semRxAxisSlaves  : AxiStreamSlaveArray(1 downto 0);

begin

   U_data : entity surf.AxiStreamRepeater
      generic map (
         TPD_G                => TPD_G,
         NUM_MASTERS_G        => 2,
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => 0)
      port map (
         -- Clock and reset
         axisClk      => sysClk,
         axisRst      => sysRst,
         -- Slave
         sAxisMaster  => dataMaster,
         sAxisSlave   => dataSlave,
         -- Masters
         mAxisMasters => dataMasters,
         mAxisSlaves  => dataSlaves);

   U_txUart : entity surf.AxiStreamRepeater
      generic map (
         TPD_G                => TPD_G,
         NUM_MASTERS_G        => 2,
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => 0)
      port map (
         -- Clock and reset
         axisClk      => sysClk,
         axisRst      => sysRst,
         -- Slave
         sAxisMaster  => txUartMaster,
         sAxisSlave   => txUartSlave,
         -- Masters
         mAxisMasters => txUartMasters,
         mAxisSlaves  => txUartSlaves);

   U_semTx : entity surf.AxiStreamRepeater
      generic map (
         TPD_G                => TPD_G,
         NUM_MASTERS_G        => 2,
         INPUT_PIPE_STAGES_G  => 0,
         OUTPUT_PIPE_STAGES_G => 0)
      port map (
         -- Clock and reset
         axisClk      => sysClk,
         axisRst      => sysRst,
         -- Slave
         sAxisMaster  => semTxAxisMaster,
         sAxisSlave   => semTxAxisSlave,
         -- Masters
         mAxisMasters => semTxAxisMasters,
         mAxisSlaves  => semTxAxisSlaves);

   GEN_VEC :
   for i in 1 downto 0 generate

      U_Vc0 : entity surf.SrpV3AxiLite
         generic map (
            TPD_G               => TPD_G,
            SLAVE_READY_EN_G    => SIMULATION_G,
            GEN_SYNC_FIFO_G     => false,
            AXI_STREAM_CONFIG_G => PHY_AXI_CONFIG_C(i))
         port map (
            -- Streaming Slave (Rx) Interface (sAxisClk domain)
            sAxisClk         => pgpRxClk(i),
            sAxisRst         => pgpRxRst(i),
            sAxisMaster      => pgpRxMasters(0+4*i),
            sAxisSlave       => pgpRxSlaves(0+4*i),
            sAxisCtrl        => pgpRxCtrl(0+4*i),
            -- Streaming Master (Tx) Data Interface (mAxisClk domain)
            mAxisClk         => pgpTxClk(i),
            mAxisRst         => pgpTxRst(i),
            mAxisMaster      => pgpTxMasters(0+4*i),
            mAxisSlave       => pgpTxSlaves(0+4*i),
            -- Master AXI-Lite Interface (axilClk domain)
            axilClk          => sysClk,
            axilRst          => sysRst,
            mAxilReadMaster  => axilReadMasters(i),
            mAxilReadSlave   => axilReadSlaves(i),
            mAxilWriteMaster => axilWriteMasters(i),
            mAxilWriteSlave  => axilWriteSlaves(i));

      U_Vc1_Tx : entity surf.PgpTxVcFifo
         generic map (
            -- General Configurations
            TPD_G              => TPD_G,
            VALID_THOLD_G      => TX_CELL_WORDS_MAX_G,
            VALID_BURST_MODE_G => true,
            -- FIFO configurations
            GEN_SYNC_FIFO_G    => false,
            FIFO_ADDR_WIDTH_G  => 10,
            -- AXI Stream Port Configurations
            APP_AXI_CONFIG_G   => PGP4_AXIS_CONFIG_C,
            PHY_AXI_CONFIG_G   => PHY_AXI_CONFIG_C(i))
         port map (
            -- Slave Port
            axisClk     => sysClk,
            axisRst     => sysRst,
            axisMaster  => dataMasters(i),
            axisSlave   => dataSlaves(i),
            -- Master Port
            pgpClk      => pgpTxClk(i),
            pgpRst      => pgpTxRst(i),
            rxlinkReady => rxlinkReady(i),
            txlinkReady => txlinkReady(i),
            pgpTxMaster => pgpTxMasters(1+4*i),
            pgpTxSlave  => pgpTxSlaves(1+4*i));

      U_Vc2_Tx : entity surf.PgpTxVcFifo
         generic map (
            -- General Configurations
            TPD_G              => TPD_G,
            VALID_THOLD_G      => TX_CELL_WORDS_MAX_G,
            VALID_BURST_MODE_G => true,
            -- FIFO configurations
            GEN_SYNC_FIFO_G    => false,
            FIFO_ADDR_WIDTH_G  => 9,
            -- AXI Stream Port Configurations
            APP_AXI_CONFIG_G   => PGP4_AXIS_CONFIG_C,
            PHY_AXI_CONFIG_G   => PHY_AXI_CONFIG_C(i))
         port map (
            -- Slave Port
            axisClk     => sysClk,
            axisRst     => sysRst,
            axisMaster  => txUartMasters(i),
            axisSlave   => txUartSlaves(i),
            -- Master Port
            pgpClk      => pgpTxClk(i),
            pgpRst      => pgpTxRst(i),
            rxlinkReady => rxlinkReady(i),
            txlinkReady => txlinkReady(i),
            pgpTxMaster => pgpTxMasters(2+4*i),
            pgpTxSlave  => pgpTxSlaves(2+4*i));

      U_Vc2_Rx : entity surf.PgpRxVcFifo
         generic map (
            TPD_G               => TPD_G,
            ROGUE_SIM_EN_G      => SIMULATION_G,
            GEN_SYNC_FIFO_G     => false,
            FIFO_ADDR_WIDTH_G   => 9,
            FIFO_PAUSE_THRESH_G => 128,
            PHY_AXI_CONFIG_G    => PHY_AXI_CONFIG_C(i),
            APP_AXI_CONFIG_G    => PGP4_AXIS_CONFIG_C)
         port map (
            -- Slave Port
            pgpClk      => pgpRxClk(i),
            pgpRst      => pgpRxRst(i),
            rxlinkReady => rxlinkReady(i),
            pgpRxMaster => pgpRxMasters(2+4*i),
            pgpRxSlave  => pgpRxSlaves(2+4*i),
            pgpRxCtrl   => pgpRxCtrl(2+4*i),
            -- Master Port
            axisClk     => sysClk,
            axisRst     => sysRst,
            axisMaster  => rxUartMasters(i),
            axisSlave   => rxUartSlaves(i));

      U_Vc3_Tx : entity surf.PgpTxVcFifo
         generic map (
            -- General Configurations
            TPD_G              => TPD_G,
            VALID_THOLD_G      => TX_CELL_WORDS_MAX_G,
            VALID_BURST_MODE_G => true,
            -- FIFO configurations
            GEN_SYNC_FIFO_G    => false,
            FIFO_ADDR_WIDTH_G  => 9,
            -- AXI Stream Port Configurations
            APP_AXI_CONFIG_G   => PGP4_AXIS_CONFIG_C,
            PHY_AXI_CONFIG_G   => PHY_AXI_CONFIG_C(i))
         port map (
            -- Slave Port
            axisClk     => sysClk,
            axisRst     => sysRst,
            axisMaster  => semTxAxisMasters(i),
            axisSlave   => semTxAxisSlaves(i),
            -- Master Port
            pgpClk      => pgpTxClk(i),
            pgpRst      => pgpTxRst(i),
            rxlinkReady => rxlinkReady(i),
            txlinkReady => txlinkReady(i),
            pgpTxMaster => pgpTxMasters(3+4*i),
            pgpTxSlave  => pgpTxSlaves(3+4*i));

      U_Vc3_Rx : entity surf.PgpRxVcFifo
         generic map (
            TPD_G               => TPD_G,
            ROGUE_SIM_EN_G      => SIMULATION_G,
            GEN_SYNC_FIFO_G     => false,
            FIFO_ADDR_WIDTH_G   => 9,
            FIFO_PAUSE_THRESH_G => 128,
            PHY_AXI_CONFIG_G    => PHY_AXI_CONFIG_C(i),
            APP_AXI_CONFIG_G    => PGP4_AXIS_CONFIG_C)
         port map (
            -- Slave Port
            pgpClk      => pgpRxClk(i),
            pgpRst      => pgpRxRst(i),
            rxlinkReady => rxlinkReady(i),
            pgpRxMaster => pgpRxMasters(3+4*i),
            pgpRxSlave  => pgpRxSlaves(3+4*i),
            pgpRxCtrl   => pgpRxCtrl(3+4*i),
            -- Master Port
            axisClk     => sysClk,
            axisRst     => sysRst,
            axisMaster  => semRxAxisMasters(i),
            axisSlave   => semRxAxisSlaves(i));

   end generate GEN_VEC;

   U_rxUart : entity surf.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => 2,
         ILEAVE_EN_G          => true,
         ILEAVE_REARB_G       => TX_CELL_WORDS_MAX_G,
         ILEAVE_ON_NOTVALID_G => true,
         MODE_G               => "PASSTHROUGH")
      port map (
         -- Clock and reset
         axisClk      => sysClk,
         axisRst      => sysRst,
         -- Slave
         sAxisMasters => rxUartMasters,
         sAxisSlaves  => rxUartSlaves,
         -- Masters
         mAxisMaster  => rxUartMaster,
         mAxisSlave   => rxUartSlave);

   U_semRx : entity surf.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => 2,
         ILEAVE_EN_G          => true,
         ILEAVE_REARB_G       => TX_CELL_WORDS_MAX_G,
         ILEAVE_ON_NOTVALID_G => true,
         MODE_G               => "PASSTHROUGH")
      port map (
         -- Clock and reset
         axisClk      => sysClk,
         axisRst      => sysRst,
         -- Slave
         sAxisMasters => semRxAxisMasters,
         sAxisSlaves  => semRxAxisSlaves,
         -- Masters
         mAxisMaster  => semRxAxisMaster,
         mAxisSlave   => semRxAxisSlave);

end mapping;
