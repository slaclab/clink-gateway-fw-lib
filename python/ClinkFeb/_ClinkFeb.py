#-----------------------------------------------------------------------------
# This file is part of the 'Camera link gateway'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'Camera link gateway', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

import surf.axi             as axi
import surf.xilinx          as xil
import surf.devices.cypress as prom
import surf.devices.linear  as linear
import surf.devices.nxp     as nxp
import surf.protocols.clink as cl
import surf.protocols.pgp   as pgp
import ClinkFeb             as feb

class ClinkFeb(pr.Device):
    def __init__(   self,
            name        = "ClinkFeb",
            description = "ClinkFeb Container",
            serial      = None,
            camType     = None,
            enI2C       = False, # disabled by default to prevent artificial timeouts due to long I2C access latency
            promLoad    = False,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        # Init Variables for only 1 serial/camType per PGP lane
        self._serial  = [serial,None]
        self._camType = [camType,None]

        # Add devices
        self.add(axi.AxiVersion(
            name        = 'AxiVersion',
            offset      = 0x00000000,
            expand      = False,
        ))

        if promLoad:
            self.add(prom.CypressS25Fl(
                name        = 'CypressS25Fl',
                offset      = 0x00001000,
                hidden      = True, # Hidden in GUI because indented for scripting
            ))

        else:

            if enI2C:

                self.add(nxp.Sa56004x(
                    name        = 'BoardTemp',
                    description = 'This device monitors the board temperature and FPGA junction temperature',
                    offset      = 0x00002000,
                    expand      = False,
                ))

                self.add(linear.Ltc4151(
                    name        = 'BoardPwr',
                    description = 'This device monitors the board power, input voltage and input current',
                    offset      = 0x00002400,
                    senseRes    = 20.E-3, # Units of Ohms
                    expand      = False,
                ))

            self.add(xil.Xadc(
                name        = 'Xadc',
                offset      = 0x00003000,
                expand      = False,
            ))

            self.add(feb.Sem(
                name        = 'Sem',
                offset      = 0x00008000,
                expand      = False,
            ))

            self.add(cl.ClinkTop(
                offset      = 0x00100000,
                serial      = self._serial,
                camType     = self._camType,
                expand      = True,
            ))

            self.add(feb.ClinkTrigCtrl(
                name        = 'TrigCtrl[0]',
                description = 'Channel A trigger control',
                offset      = 0x00200000,
                expand      = True,
            ))

            self.add(pgp.Pgp2bAxi(
                name    = 'PgpMon[0]',
                offset  = 0x00400000,
                writeEn = False,
                expand  = False,
            ))

            self.add(pgp.Pgp4AxiL(
                name    = 'PgpMon[1]',
                offset  = 0x00410000,
                numVc   = 4,
                writeEn = True,
                expand  = False,
            ))
