import qtm
import asyncio
import logging
logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("example")

# def on_packet(packet):
#     """ Callback function that is called everytime a data packet arrives from QTM """
#     print("Framenumber: {}".format(packet.framenumber))
#     header, markers = packet.get_3d_markers()
#     print("Component info: {}".format(header))
#     for marker in markers:
#         print("\t", marker)
async def setup():
    """ Main function """
    connection = await qtm.connect("127.0.0.1")
    if connection is None:
        return

    async with qtm.TakeControl(connection, "password"):
        result = await connection.close()
        if result == b"Closing connection":
            await connection.await_event(qtm.QRTEvent.EventConnectionClosed)

        await connection.new()
        await connection.await_event(qtm.QRTEvent.EventConnected)

        await connection.start()
        await connection.await_event(qtm.QRTEvent.EventWaitingForTrigger)

        await connection.trig()
        await connection.await_event(qtm.QRTEvent.EventCaptureStarted)
        print("holaa")

        await asyncio.sleep(2)

        await connection.set_qtm_event()
        await asyncio.sleep(0.001)
        await connection.set_qtm_event("with_label")

        await asyncio.sleep(3)

        await connection.stop()
        await connection.await_event(qtm.QRTEvent.EventCaptureStopped)

        await connection.save("./test/measurement.qtm")

        await asyncio.sleep(3)

        await connection.close()

    connection.disconnect()


if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    loop.run_until_complete(setup())
    loop.close()