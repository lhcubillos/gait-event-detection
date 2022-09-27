import asyncio
import csv
import platform
import struct
import time
import warnings
from collections import defaultdict, deque
from typing import Any

import numpy as np
from bleak import BleakClient
from matplotlib import pyplot as plt
from scipy import stats
from datetime import datetime

warnings.filterwarnings("once")

from threading import Thread

if platform.system() == "Windows":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

address = "9C:9C:1F:E0:E1:96"
SERVICE_UUID = "917649A1-D98E-11E5-9EEC-0002A5D5C51B"


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
    client: BleakClient = None

    def __init__(self, address, read_char) -> None:
        self.address = address
        self.read_charact = read_char

        self.connected = False
        self.connected_device = False
        self.finishing = False

        self.loop = asyncio.new_event_loop()
        self.last_update = 0
        self.updates = []
        self.data = []

        print(f"Connecting to IMU")
        self.client = BleakClient(self.address)

        self.p_thread = Thread(target=self.plotter_thread, daemon=True)
        self.p_thread.start()

    def plotter_thread(self):
        live_plotter = LivePlotter()
        while not self.finishing:
            if len(self.data) > 1:
                live_plotter.run_iteration(*self.data[-1]["gyro"])
        live_plotter.cleanup()

    def on_disconnect(self, client: BleakClient):
        self.connected = False
        # Put code here to handle what happens on disconnet.
        print(f"Disconnected from IMU!")

    async def cleanup(self):
        self.finishing = True
        if self.client:
            await self.client.stop_notify(self.read_charact)
            await self.client.disconnect()

    async def manager(self):
        print("Starting connection manager.")
        while True:
            await self.connect()

    async def connect(self):
        if self.connected:
            return
        try:
            await self.client.connect()
            self.connected = self.client.is_connected
            if self.connected:
                print(f"Connected to IMU")
                self.client.set_disconnected_callback(self.on_disconnect)
                # Start notification process
                await self.client.start_notify(
                    self.read_charact,
                    self.notification_handler,
                )
                while True:
                    if not self.connected:
                        break
                    await asyncio.sleep(2.0)
            else:
                print(f"Failed to connect to IMU")
        except Exception as e:
            print(e)

    def notification_handler(self, sender: str, data: Any):
        data_all = list(struct.unpack("fffffffff", data[:36]))
        euler = data_all[:3]
        accel = data_all[3:6]
        gyro = data_all[6:9]
        timestamp = int.from_bytes(data[36:], "big", signed=False)

        self.data.append(
            {"timestamp": timestamp, "euler": euler, "accel": accel, "gyro": gyro}
        )
        # # Modify the first one to be between -180 and 180
        # if len(self.euler) > 0:
        #     self.euler[0] -= 180
        now = time.time()
        # print(f"time between: {now - self.last_update}")
        if now - self.last_update < 1000:
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
            modified_dict = [
                {
                    "timestamp": dic["timestamp"],
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

    def run(self):
        try:
            self.loop.run_until_complete(self.manager())
        except KeyboardInterrupt:
            print()
            print("User stopped program.")
            self.save_data()
        finally:
            print("Disconnecting...")
            print(stats.describe(self.updates))
            self.loop.run_until_complete(connection.cleanup())
            self.loop.close()


if __name__ == "__main__":
    connection = Connection(address, SERVICE_UUID)
    connection.run()
