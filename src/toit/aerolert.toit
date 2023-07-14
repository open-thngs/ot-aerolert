import gpio
import i2c
import net
import mqtt
import ntp
import esp32 show adjust_real_time_clock


import ringbuffer show *
import dps368
import dps368.config as cfg

THREASHOLD ::= 5.0

CLIENT_ID ::= "AerolertESP32"
HOST      ::= "192.168.178.26"
PORT      ::= 1883

client := ?

main:
  adjust_realtime
  network := net.open
  transport := mqtt.TcpTransport network --host=HOST
  client = mqtt.Client --transport=transport
  client.start --client_id=CLIENT_ID

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
    print "$(%.2f value)"
    buffer.append value
    average := buffer.average
    std_deviation := buffer.std_deviation
    deviation := THREASHOLD * std_deviation

    if (value > average + deviation) or (value < average - deviation):
      peak_detected

    sleep --ms=200

peak_detected:
  time := Time.now.local
  payload := "Peak Detected at $(%02d time.day)-$(%02d time.month)-$(%04d time.year)-$(%02d time.h):$(%02d time.m):$(%02d time.s)"
  //print payload
  client.publish "home/aerolert" payload.to_byte_array

adjust_realtime:
  now := Time.now
  if now < (Time.from_string "2022-01-10T00:00:00Z"):
    result ::= ntp.synchronize
    if result:
      adjust_real_time_clock result.adjustment
      print "Set time to $Time.now by adjusting $result.adjustment"
    else:
      print "ntp: synchronization request failed"
  else:
    print "We already know the time is $now"
