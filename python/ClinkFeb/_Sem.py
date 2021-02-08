#!/usr/bin/env python3
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

class Sem(pr.Device):
    def __init__(self,
            name             = 'Sem',
            description      = 'FEB Soft Error Mitigation Module',
            **kwargs):

        super().__init__(
            name        = name,
            description = description,
            **kwargs
        )

        self.add(pr.RemoteVariable(
            name="SemStatus",
            offset=0x00,
            bitSize=7,
            bitOffset=0,
            mode = 'RO',
            base=pr.UInt,
            pollInterval=5,
            enum={
                0:'Initialization',
                1:'Undef_0x1',
                2:'Observation',
                4:'Correction',
                8:'Classification',
                16:'Injection',
                32:'Idle',
                95:'Halt'}))

        self.add(pr.RemoteVariable(
            name="Essential",
            offset=0x00,
            bitSize=1,
            bitOffset=7,
            mode = 'RO',
            base=pr.Bool,
            pollInterval=5))


        self.add(pr.RemoteVariable(
            name="Uncorrectable",
            offset=0x00,
            bitSize=1,
            bitOffset=8,
            mode = 'RO',
            base=pr.Bool,
            pollInterval=5))

        self.add(pr.RemoteVariable(
            name="HeartbeatCount",
            offset=0x04,
            bitSize=32,
            bitOffset=0,
            mode = 'RO',
            base=pr.UInt,
            pollInterval=5))


        self.add(pr.RemoteVariable(
            name="InjectBitAddress",
            offset=0x10,
            bitSize=5,
            bitOffset=0,
            base=pr.UInt))

        self.add(pr.RemoteVariable(
            name="InjectWordAddress",
            offset=0x10,
            bitSize=7,
            bitOffset=5,
            base=pr.UInt))

        self.add(pr.RemoteVariable(
            name="InjectLinearFrame",
            offset=0x10,
            bitSize=17,
            bitOffset=12,
            base=pr.UInt))

        self.add(pr.RemoteVariable(
            name="InjectAddrHigh",
            offset=0x10,
            bitSize=11,
            bitOffset=29,
            base=pr.UInt))


        countNames = ['InitilizationCount', 'ObservationCount', 'CorrectionCount', 'ClassificationCount',
                      'InjectionCount', 'IdleCount', 'EssentialCount', 'UncorrectableCount']

        for i, name in enumerate(countNames):
            self.add(pr.RemoteVariable(
                name = name,
                mode = 'RO',
                offset = 0x20 + (i*4),
                bitSize = 12,
                bitOffset = 0,
                base = pr.UInt,
                disp = '{:d}'))

        self.CorrectionCount.pollInterval = 5

        self.add(pr.RemoteCommand(
            name="InjectStrobe",
            offset=0x0C,
            bitSize=1,
            bitOffset=0,
            base=pr.UInt,
            function=pr.BaseCommand.touchOne))

        self.add(pr.RemoteVariable(
            name         = 'FpgaIndex',
            description  = 'FPGA Index',
            offset       = 0xFC,
            bitSize      = 4,
            mode         = 'RW',
        ))

        @self.command(description='Direct a transition to the IDLE state through the Injection interface')
        def InjectIdleState():
            self.InjectAddrHigh.set(0xE00>>1)
            self.InjectStrobe()

        @self.command(description='Direct a transition to the OBSERVATION state through the Injection interface')
        def InjectObservationState():
            self.InjectAddrHigh.set(0xA00>>1)
            self.InjectStrobe()

        @self.command(description='Inject a SEM error')
        def InjectError():
            self.InjectIdleState()
            self.InjectAddrHigh.set(0xC00>>1)
            self.InjectStrobe()
            self.InjectObservationState()

        @self.command(description='Inject a SEM Reset')
        def InjectReset():
            self.InjectIdleState()
            self.InjectAddrHigh.set(0xB00>>1)
            self.InjectStrobe()
