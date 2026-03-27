import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, First

class QspiPmod:

    def __init__(self, dut, filename, verbose=False):
        self.dut = dut
        self.uio_in = dut.uio_in
        self.uio_out = dut.uio_out
        self.uio_oe = dut.uio_oe
        self.cs0 = dut.cs0
        self.sck = dut.sck
        self.qspi_in = dut.qspi_in
        self.qspi_out = dut.qspi_out
        self.qspi_oe = dut.qspi_oe
        self.filename = filename
        self.verbose = verbose
        self.mode = "unknown"

    def __enter__(self):
        self.file = open(self.filename, "rb")
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.file.close()

    async def main_loop(self):
        while True:
            await FallingEdge(self.cs0)
            cocotb.start_soon(self.transaction())

    async def rise_or_eot(self):
        await First(RisingEdge(self.cs0), RisingEdge(self.sck))
        return self.cs0.value == 1

    async def fall_or_eot(self):
        await First(RisingEdge(self.cs0), FallingEdge(self.sck))
        return self.cs0.value == 1

    async def transaction(self):
        # read instruction
        instruction = ""
        while True:
            if await self.rise_or_eot():
                return
            if self.mode in ("unknown", "qpi"):
                assert self.uio_oe.value == 0b11111111
                instruction += str(self.qspi_out.value)
            elif self.mode == "spi":
                assert self.uio_oe.value == 0b11001011
                instruction += str(self.qspi_out.value[0])
            else:
                assert False, "invalid mode"
            if len(instruction) >= 8:
                break
        assert len(instruction) == 8
        if self.mode == "unknown":
            assert instruction == "11111111"
            self.mode = "spi"
            return
        elif self.mode == "spi":
            assert instruction == "00111000"
            self.mode = "qpi"
            return
        elif self.mode == "qpi":
            assert instruction == "11101011"
        else:
            assert False, "invalid mode"
        # read address
        assert self.mode == "qpi"
        address = ""
        while True:
            if await self.rise_or_eot():
                return
            assert self.uio_oe.value == 0b11111111
            address += str(self.qspi_out.value)
            if len(address) >= 24:
                break
        assert len(address) == 24
        pos = int(address, 2)
        # read dummy
        if await self.rise_or_eot():
            return
        assert self.uio_oe.value == 0b11111111
        assert self.qspi_out.value == 0b1111
        if await self.rise_or_eot():
            return
        assert self.uio_oe.value == 0b11001001
        if await self.fall_or_eot():
            return
        # write data
        while True:
            self.file.seek(pos)
            data = ord(self.file.read(1))
            if self.verbose:
                self.dut._log.info(f"QSPI read: {pos:06x} => {data:02x}")
            pos += 1
            self.qspi_in.value = (data >> 4) & 0xf
            if await self.fall_or_eot():
                return
            self.qspi_in.value = data & 0xf
            if await self.fall_or_eot():
                return


async def qspi_pmod(dut, filename, verbose):
    with QspiPmod(dut, filename, verbose) as qspi:
        await qspi.main_loop()

