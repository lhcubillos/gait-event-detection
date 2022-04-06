from digi.xbee.devices import Raw802Device
import time

device = Raw802Device("COM7", 230400)
time_sent = 0
try:
    device.open()
    print(device._get_operating_mode())
    # xbee_network = device.get_network()
    # remote_device = xbee_network.discover_device("REMOTE")
    # if remote_device is None:
    #     print("Could not find the remote device")
    #     exit(1)

    # def data_receive_callback(xbee_message):
    #     global time_sent
    #     print(time.time() - time_sent)

    # # device.add_data_received_callback(data_receive_callback)
    # addr_16 = remote_device.get_16bit_addr()
    # print("Sending data to %s >> %s..." % (remote_device.get_64bit_addr(), "1"))
    while True:
        time_sent = time.time()
        device.send_data_broadcast(b"PING")
        msg = device.read_data()
        print(msg, time.time() - time_sent)
        time.sleep(1)

finally:
    if device is not None and device.is_open():
        device.close()
