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

import rogue

import datetime
import click
import os
import threading

class SemAsciiFileWriter(rogue.interfaces.stream.Slave):
    def __init__(self, index=0, dumpDir=`seu`):
        rogue.interfaces.stream.Slave.__init__(self)

        now = datetime.datetime.now()
        fpath = os.path.abspath(now.strftime(f'{dumpDir}/SEU_Monitor[{index}]-%Y%m%d_%H%M%S.dat'))
        print(f'fpath: {fpath}')

        self.dataFile = open(fpath, 'a')
        self.lock     = threading.Lock()
        self.index    = index

    def close(self):
        self.dataFile.close()

    def _acceptFrame(self, frame):
        with self.lock:
            ba = bytearray(frame.getPayload())
            frame.read(ba, 0)
            s = ba.rstrip(bytearray(1))
            s = s.decode('utf8')
            s = f'{datetime.datetime.now()} - {s}'
            errMsg = f'SEU[{self.index}]:' + s
            click.secho(errMsg, bg='red')
            self.dataFile.write(s)
