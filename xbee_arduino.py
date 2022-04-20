"""
Detection callback w/ scanner
--------------
Example showing what is returned using the callback upon detection functionality
Updated on 2020-10-11 by bernstern <bernie@allthenticate.net>
"""

import asyncio
import csv
import qtm
import platform
import struct
import time
import warnings
from collections import defaultdict, deque
from typing import Any
from digi.xbee.serial import XBeeSerialPort
import serial

import numpy as np
from matplotlib import pyplot as plt
from scipy import stats
from datetime import datetime
import logging
logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("example")

warnings.filterwarnings("once")

from threading import Thread

if platform.system() == "Windows":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

SERIAL_PORT = "COM6"
MSG_LENGTH = 40
BAUDRATE = 230400
FULL_TURNAROUND_TIME = 32.020 #milliseconds


class LivePlotter:
    FREQUENCY = 30
    MAX_VALUE = 10000

    def __init__(self):
        self.fig = None
        self.ax = None
        self.line1 = None
        self.line2 = None
        self.line3 = None
        self.axbackground = None
        maxsize = 500
        self.y = deque(maxlen=maxsize)
        self.z = deque(maxlen=maxsize)
        self.x = deque(maxlen=maxsize)
        self.t = deque(maxlen=maxsize)
        self.first_time = None
        self.frequency = LivePlotter.FREQUENCY

        self.init_process()

    def init_process(self):
        self.fig = plt.figure()
        self.ax = self.fig.add_subplot(1, 1, 1)
        (self.line1,) = self.ax.plot([], lw=2)
        (self.line2,) = self.ax.plot([], lw=2)
        (self.line3,) = self.ax.plot([], lw=2)
        self.axbackground = self.fig.canvas.copy_from_bbox(self.ax.bbox)
        self.fig.canvas.draw()
        plt.show(block=False)
        plt.legend(["X", "Y", "Z"])

    def handle_new_data(self, x, y, z):
        if self.first_time is None:
            self.first_time = time.time()

        self.t.append(time.time() - self.first_time)
        self.x.append(x)
        self.y.append(y)
        self.z.append(z)

        # Update lines
        self.line1.set_data(np.array(self.t), np.array(self.x))
        self.line2.set_data(np.array(self.t), np.array(self.y))
        self.line3.set_data(np.array(self.t), np.array(self.z))
        if min(self.t) != max(self.t):
            self.ax.set_xlim(min(self.t), max(self.t))
        self.ax.set_ylim(
            min(min(self.x), min(self.y), min(self.z)),
            max(max(self.x), max(self.y), max(self.z)),
        )

    def run_iteration(self, x, y, z):
        self.handle_new_data(x, y, z)
        self.fig.canvas.draw()

        self.fig.canvas.flush_events()

    def cleanup(self):
        plt.close(self.fig)


class Connection:
    def __init__(self) -> None:
        self.conn = XBeeSerialPort(BAUDRATE, SERIAL_PORT, timeout=0.1)
        self.connected = False
        self.connected_device = False
        self.finishing = False

        self.loop = asyncio.new_event_loop()
        self.last_update = 0
        self.updates = []
        self.data = []

        # QTM
        self.qtm_connection = None

        self.p_thread = Thread(target=self.plotter_thread, daemon=True)
        self.p_thread.start()

    def plotter_thread(self):
        live_plotter = LivePlotter()
        while not self.finishing:
            if len(self.data) > 1:
                live_plotter.run_iteration(*self.data[-1]["gyro"])
        live_plotter.cleanup()

    def cleanup(self):
        self.finishing = True
        self.stop_arduino()
        if self.connected:
            self.conn.close()
        if self.qtm_connection is not None:
            self.loop.run_until_complete(self.qtm_connection.release_control())

        self.loop.close()

    def connect(self):
        if self.connected:
            return
        self.conn.open()
        self.connected = self.conn.is_interface_open
        if self.connected:
            print(f"Connected to IMU")
        else:
            print(f"Failed to connect to IMU")
        self.last_update = time.time()

        # QTM
        self.qtm_connection = self.loop.run_until_complete(qtm.connect("127.0.0.1"))
        if self.qtm_connection is None:
            raise Exception("Could not connect to QTM")
        # Take control
        self.loop.run_until_complete(self.qtm_connection.take_control("password"))
        # Create new capture file
        self.loop.run_until_complete(self.qtm_connection.new())
        self.loop.run_until_complete(
            self.qtm_connection.await_event(qtm.QRTEvent.EventConnected)
        )

    def read_message(self):
        msg = self.conn.read(MSG_LENGTH)
        if len(msg) < MSG_LENGTH:
            print("Message timeout")
            self.conn.flush()
            return
        # First, check if the data has started or not.
        # Check if all bytes are equal to .
        data_all = list(struct.unpack("fffffffff", msg[:36]))
        euler = data_all[:3]
        accel = data_all[3:6]
        gyro = data_all[6:9]
        timestamp = int.from_bytes(msg[36:], "big", signed=False)

        self.data.append(
            {"timestamp": timestamp, "euler": euler, "accel": accel, "gyro": gyro}
        )

        now = time.time()
        self.updates.append(now - self.last_update)
        self.last_update = now

    def save_data(self):
        # Will save as csv
        if len(self.data) == 0:
            return
        now = datetime.now()
        with open(
            f"results/{now.strftime('%Y_%m_%d__%H_%M_%S')}.csv", "w", newline=""
        ) as f:
            keys = [
                "timestamp",
                "euler_x",
                "euler_y",
                "euler_z",
                "accel_x",
                "accel_y",
                "accel_z",
                "gyro_x",
                "gyro_y",
                "gyro_z",
            ]
            dict_writer = csv.DictWriter(f, keys)
            dict_writer.writeheader()
            # Timestamp is delayed by half of the turnaround time
            modified_dict = [
                {
                    "timestamp": dic["timestamp"] + FULL_TURNAROUND_TIME/2,
                    "euler_x": dic["euler"][0],
                    "euler_y": dic["euler"][1],
                    "euler_z": dic["euler"][2],
                    "accel_x": dic["accel"][0],
                    "accel_y": dic["accel"][1],
                    "accel_z": dic["accel"][2],
                    "gyro_x": dic["gyro"][0],
                    "gyro_y": dic["gyro"][1],
                    "gyro_z": dic["gyro"][2],
                }
                for dic in self.data
            ]
            dict_writer.writerows(modified_dict)

    def start_arduino(self):
        # Send message to Arduino to start the data output
        self.conn.write(b".")

    def stop_arduino(self):
        self.conn.write(b",")

    async def start_qtm(self):
        await self.qtm_connection.start()
        await self.qtm_connection.await_event(qtm.QRTEvent.EventWaitingForTrigger)
        await self.qtm_connection.trig()
        # await self.qtm_connection.await_event(qtm.QRTEvent.EventCaptureStarted)

    async def stop_qtm(self):
        await self.qtm_connection.stop()
        await self.qtm_connection.await_event(qtm.QRTEvent.EventCaptureStopped)
        now = datetime.now()
        await self.qtm_connection.save(
            f"LC042022\measurement_{now.strftime('%Y_%m_%d__%H_%M_%S')}.qtm"
        )

    def run(self):
        self.connect()
        # Start QTM recording
        self.loop.run_until_complete(self.start_qtm())
        # Send the start signal to Arduino, and start receiving values
        # QTM and Arduino will be delayed by half of the full turnaround time.
        self.start_arduino()
        try:
            while True:
                self.read_message()
        except KeyboardInterrupt:
            print()
            print("User stopped program.")
            self.save_data()
        finally:
            print("Disconnecting...")
            self.loop.run_until_complete(self.stop_qtm())
            print(stats.describe(self.updates))
            self.cleanup()


if __name__ == "__main__":
    connection = Connection()
    connection.run()
