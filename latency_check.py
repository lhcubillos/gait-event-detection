"""
Detection callback w/ scanner
--------------
Example showing what is returned using the callback upon detection functionality
Updated on 2020-10-11 by bernstern <bernie@allthenticate.net>
"""

import asyncio
import platform
import struct
import time
from typing import Any
from collections import deque

import numpy as np
from bleak import BleakClient
from matplotlib import pyplot as plt
from scipy import stats
import warnings

warnings.filterwarnings("once")

from threading import Thread

if platform.system() == "Windows":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

address = "9C:9C:1F:E0:E1:96"
LATENCY_OUT_UUID = "6192e000-3f65-4afa-91f5-3d671e525c45"
LATENCY_IN_UUID = "e83f52ee-0d66-4430-b171-92fc413631e2"


class Connection:
    client: BleakClient = None

    def __init__(self, address, read_char) -> None:
        self.address = address
        self.read_charact = read_char

        self.connected = False
        self.connected_device = False
        self.finishing = False

        self.loop = asyncio.new_event_loop()

        # Latency
        self.msg_counter = 0
        self.msg_length = 40
        self.last_latency_ts = 0
        self.latency_times = []

        print(f"Connecting to IMU")
        self.client = BleakClient(self.address)

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
                    # Test latency
                    bytes_to_send = bytearray(
                        self.msg_counter.to_bytes(self.msg_length, byteorder="big")
                    )
                    self.last_latency_ts = time.time()
                    await self.client.write_gatt_char(LATENCY_OUT_UUID, bytes_to_send)
                    self.msg_counter += 1

                    await asyncio.sleep(0.25)
            else:
                print(f"Failed to connect to IMU")
        except Exception as e:
            print(e)

    def notification_handler(self, sender: str, data: Any):
        # First, check that the number is the same I have stored.
        t = time.time()
        num = int.from_bytes(data, byteorder="big")
        t_since = t - self.last_latency_ts
        if num != self.msg_counter - 1:
            print(num, self.msg_counter)
            raise Exception("Numbers in latency check do not match")
        print(t_since / 2)
        self.latency_times.append(t_since)

    def run(self):
        try:
            self.loop.run_until_complete(self.manager())
        except KeyboardInterrupt:
            print()
            print("User stopped program.")
            print("Latency:")
            print(stats.describe(self.latency_times))
        finally:
            print("Disconnecting...")
            self.loop.run_until_complete(connection.cleanup())
            self.loop.close()


if __name__ == "__main__":
    connection = Connection(address, LATENCY_IN_UUID)
    connection.run()
