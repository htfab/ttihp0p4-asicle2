import cocotb
from cocotb.triggers import Timer

async def send_gamepad_state(dut, state):
    for s in state:
        if s == "1":
            dut.ui_in.value = 0b01000000
            await Timer(3500, unit="ns")
            dut.ui_in.value = 0b01100000
            await Timer(5000, unit="ns")
            dut.ui_in.value = 0b01000000
            await Timer(5500, unit="ns")
        elif s == "0":
            dut.ui_in.value = 0b00000000
            await Timer(3500, unit="ns")
            dut.ui_in.value = 0b00100000
            await Timer(5000, unit="ns")
            dut.ui_in.value = 0b00000000
            await Timer(5500, unit="ns")
        else:
            assert False, "invalid button state"
    dut.ui_in.value = 0b00010000
    await Timer(11000, unit="ns")
    dut.ui_in.value = 0b00000000


button_states = {
    "none":    "111111111111000000000000",
    "up":      "111111111111000010000000",  # up
    "down":    "111111111111000001000000",  # down
    "left":    "111111111111000000100000",  # left
    "right":   "111111111111000000010000",  # right
    "guess":   "111111111111000000001000",  # A
    "debug":   "111111111111100000000000",  # B
    "shift":   "111111111111001000000000",  # select
    "softnew": "111111111111000100000000",  # start
    "new":     "111111111111001100000000",  # select + start
    "peek":    "111111111111001000000100",  # select + X
    "roll":    "111111111111011000000000",  # select + Y
}

async def send_gamepad_input(dut, button, release=True, release_time_us=8000, verbose=False):
    if verbose:
        dut._log.info(f"Setting gamepad input: {button}")
    await send_gamepad_state(dut, button_states[button])
    if release:
        await Timer(release_time_us, unit="us")
        if verbose:
            dut._log.info(f"Setting gamepad input: none")
        await send_gamepad_state(dut, button_states["none"])

direct_states = {
    "none":   0b00000000,
    "up":     0b00000001,
    "down":   0b00000010,
    "left":   0b00000100,
    "right":  0b00001000,
    "guess":  0b00010000,
    "new":    0b00100000,
    "peek":   0b01000000,
    "roll":   0b10000000,
}

async def send_direct_input(dut, button, release=True, release_time_us=8000, verbose=False):
    if verbose:
        dut._log.info(f"Setting direct input: {button}")
    dut.ui_in.value = direct_states[button]
    if release:
        await Timer(release_time_us, unit="us")
        if verbose:
            dut._log.info(f"Setting direct input: none")
        dut.ui_in.value = direct_states["none"]

