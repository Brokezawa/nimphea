## MCP23X17 GPIO Expander Module - 16-bit I/O Expansion via I2C/SPI
##
## Barebones driver for MCP23017/MCP23S17 16-bit I/O expanders.
## Currently supports I2C transport only (polling mode).

import nimphea
import nimphea/per/i2c


type
  MCPPort* = enum
    MCP_PORT_A = 0
    MCP_PORT_B = 1

  Mcp23017TransportConfig* = object
    # The I2C bus comes from the type parameter (Mcp23017[P]); only the
    # transport settings below are user-controlled.
    speed*: I2CSpeed
    scl*, sda*: Pin
    address*: uint8

  Mcp23017Config*[P: static I2CPeripheral] = object
    transport_config*: Mcp23017TransportConfig

  Mcp23017*[P: static I2CPeripheral] = object
    i2c: I2cHandle[P]
    address: uint8
    pinData: uint16

const MCP_DEFAULT_ADDR* = 0x27'u8

proc defaults*(config: var Mcp23017TransportConfig) =
  config.speed = I2C_1MHZ
  config.scl = newPin(PORTB, 8)
  config.sda = newPin(PORTB, 9)
  config.address = MCP_DEFAULT_ADDR

proc defaults*[P](config: var Mcp23017Config[P]) =
  config.transport_config.defaults()

proc init*[P](mcp: var Mcp23017[P], config: Mcp23017Config[P]) =
  mcp.address = config.transport_config.address

  mcp.i2c = initI2C[P](
    config.transport_config.scl,
    config.transport_config.sda,
    config.transport_config.speed,
    I2C_MASTER
  )
  
  # Configure IOCON: sequential mode disabled
  discard mcp.i2c.writeRegister(mcp.address, 0x0A, 0b00100000'u8, 10)
  
  # Enable all pull-ups
  discard mcp.i2c.writeRegister(mcp.address, 0x0C, 0xFF'u8, 10) # GPPU_A
  discard mcp.i2c.writeRegister(mcp.address, 0x0D, 0xFF'u8, 10) # GPPU_B

proc portMode*[P](mcp: var Mcp23017[P], port: MCPPort, directions, pullups, inverted: uint8) =
  let regBase = if port == MCP_PORT_A: 0x00'u8 else: 0x01'u8
  discard mcp.i2c.writeRegister(mcp.address, regBase, directions, 10)
  discard mcp.i2c.writeRegister(mcp.address, regBase + 0x0C, pullups, 10)
  discard mcp.i2c.writeRegister(mcp.address, regBase + 0x02, inverted, 10)

proc digitalWrite*[P](mcp: var Mcp23017[P], port: MCPPort, value: uint8) =
  let reg = if port == MCP_PORT_A: 0x12'u8 else: 0x13'u8
  discard mcp.i2c.writeRegister(mcp.address, reg, value, 10)

proc readPort*[P](mcp: var Mcp23017[P], port: MCPPort): uint8 =
  let reg = if port == MCP_PORT_A: 0x12'u8 else: 0x13'u8
  let (res, val) = mcp.i2c.readRegister(mcp.address, reg, 10)
  return val

proc read*(mcp: var Mcp23017): uint16 =
  let a = mcp.readPort(MCP_PORT_A)
  let b = mcp.readPort(MCP_PORT_B)
  mcp.pinData = a.uint16 or (b.uint16 shl 8)
  return mcp.pinData

proc getPin*(mcp: Mcp23017, pin: uint8): bool =
  return ((mcp.pinData shr pin) and 1) != 0
