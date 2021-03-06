#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import division, print_function
from mimetypes import init

from digi.xbee.serial import XBeeSerialPort
import serial
import numpy
from timeit import default_timer as getTime

SERIAL_PORT = "COM6"
ITERATION_COUNT = 10000
MSG_LENGTH = 40

try:
    sconn = XBeeSerialPort(230400, SERIAL_PORT, timeout=0.1)
    sconn.open()
except serial.SerialException as e:
    print("Check SERIAL_PORT variable is correct for device being tested.")
    raise e

# clear anything in serial rx
while sconn.readline():
    pass

# Test time it takes to send a serial message to the labhackers device
# and receive the serial reply.
init_time = getTime()
results = numpy.zeros(ITERATION_COUNT, dtype=numpy.float64)
num_timeouts = 0
for i in range(ITERATION_COUNT):
    tx_time = getTime()
    msg = b"A" * MSG_LENGTH + b"."
    sconn.write(msg)
    r = sconn.read(MSG_LENGTH + 1)
    rx_time = getTime()
    if r:
        results[i] = rx_time - tx_time
    else:
        print(r)
        print(i)
        num_timeouts +=1
        results[i] = numpy.nan

total_time = getTime() - init_time
sconn.close()

# Convert times to msec.
results = results * 1000.0

print("Results")
print(f"\tMsg length: {MSG_LENGTH}")
print("\tCount: {}".format(results.shape))
print("\tAverage: {:.3f} msec".format(numpy.nanmean(results)))
print("\tMedian: {:.3f} msec".format(numpy.nanmedian(results)))
print("\tMin: {:.3f} msec".format(numpy.nanmin(results)))
print("\tMax: {:.3f} msec".format(numpy.nanmax(results)))
print("\tStdev: {:.3f} msec".format(numpy.nanstd(results)))
print(f"\tTotal time: {total_time:.3f} s")
print(f"\tAvg frequency: {results.shape[0] / total_time:.2f} Hz")
print(f"\tTimeouts: {num_timeouts}")
