#!/usr/bin/python

# xdrtoc.py
#
# Read Sun XDRTOC files to determine contents/layout of tape and CD-ROM install media
# These are a binary-packed data format so we are using Python struct() to read it.

import struct

# header/magic: 0x674D2309
