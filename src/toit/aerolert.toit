import gpio
import i2c

import ringbuffer show *
import dps368
import dps368.config as cfg

THREASHOLD ::= 5.0

main:
  buffer := RingBuffer 32
  bus := i2c.Bus
    --sda=gpio.Pin 21
    --scl=gpio.Pin 22

  device := bus.device dps368.I2C_ADDRESS_PD
  dps368 := dps368.DPS368 device
  dps368.init cfg.MEASURE_RATE.TIMES_4 cfg.OVERSAMPLING_RATE.TIMES_64 cfg.MEASURE_RATE.TIMES_4 cfg.OVERSAMPLING_RATE.TIMES_1

  dps368.measureContinousPressureAndTemperature

  print "ProductId:  $dps368.productId"
  print "Config: $dps368.measure_config"

  value := dps368.pressure
  print "Aerolert running..."
  while true:
    value = dps368.pressure
    //print "$(%.2f value)"
    buffer.append value
    average := buffer.average
    std_deviation := buffer.std_deviation
    deviation := THREASHOLD * std_deviation

    if (value > average + deviation) or (value < average - deviation):
      peak_detected

    sleep --ms=200

peak_detected:
  time := Time.now.local
  print "$(%02d time.day)-$(%02d time.month)-$(%04d time.year)-$(%02d time.h):$(%02d time.m):$(%02d time.s)"
