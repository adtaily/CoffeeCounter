-- pinout mapping:
-- http://cdn.instructables.com/FPV/E4YC/IKLFP40J/FPVE4YCIKLFP40J.MEDIUM.jpg

dofile "config.lua"

ALARM_ID_WIFI         = 0;
ALARM_ID_YELLOW_BLINK = 1;
ALARM_ID_ADC_CHECK    = 2;
ALARM_ID_HEARTBIT     = 3;

YELLOW_LED_PIN = 6; -- GPIO13
RED_LED_PIN    = 7; -- GPIO12

-- called at the end of file
function main()
  gpio.mode(RED_LED_PIN, gpio.OUTPUT);
  gpio.mode(YELLOW_LED_PIN, gpio.OUTPUT);

  red_led_on();

  wifi.sta.autoconnect(0);
  wifi.setphymode(wifi.PHYMODE_N);
  wifi.setmode(wifi.STATION);
  wifi.sta.config(WIFI_SSID, WIFI_PASS);
  wifi.sta.sethostname(WIFI_HOST);

  setup();
end

function setup()
  tmr.alarm(ALARM_ID_WIFI, 1000, 1, function()
    if wifi.sta.getip() == nil then
      print("IP unavailable, waiting");
    else
      tmr.stop(ALARM_ID_WIFI);
      print("Config done, IP is " .. wifi.sta.getip());
      print("hostname: " .. wifi.sta.gethostname());

      post_rebooted_info();
      attach_heartbeat_callback();
      start_http_server();
      check_adc();

      red_led_off();
    end
  end)
end

function start_http_server()
  print("Starting http server")

  srv = net.createServer(net.TCP, 30)
  srv:listen(80, function(conn)
    conn:on("receive", function(client,request)
      print("Got http request")

      local response_body = "Coffe Counter is alive!";
      local response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: " .. response_body:len() .. "\r\n\r\n" .. response_body;

      client:send(response);
      client:close();

      collectgarbage();
    end)
  end)
end

function red_led_on()
  gpio.write(RED_LED_PIN, gpio.HIGH);
end

function red_led_off()
  gpio.write(RED_LED_PIN, gpio.LOW);
end

function blink_yellow_led(duration_in_millis, callback)
  gpio.write(YELLOW_LED_PIN, gpio.HIGH);
  tmr.alarm(ALARM_ID_YELLOW_BLINK, duration_in_millis, tmr.ALARM_SINGLE, function()
    gpio.write(YELLOW_LED_PIN, gpio.LOW);
    if callback ~= nil then
      callback();
    end
  end)
end

function check_adc()
  local voltage = adc.read(0);

  if voltage >= 1000 or (voltage >= 400 and voltage <= 500)  then
    print("button press detected");

    while (adc.read(0) > 100) do
      -- wait until button is released
    end

    blink_yellow_led(1000, function()
      tmr.alarm(2, 10, tmr.ALARM_SINGLE, check_adc);
      post_coffee_counter();
    end)
  else
    tmr.alarm(2, 10, tmr.ALARM_SINGLE, check_adc);
  end
end

function post_coffee_counter()
  http.post('http://api.thingspeak.com/update?api_key=' .. THINGSPEAK_APIKEY .. '&field1=1', '', '',
    function(code, data)
      print("coffee counter request sent");
    end)
end

function post_rebooted_info()
  http.post('http://api.thingspeak.com/update?api_key=' .. THINGSPEAK_APIKEY .. '&field2=1', '', '');
end

function attach_heartbeat_callback()
  -- post hearbeat every 5 minutes (300_000 miliseconds)
  tmr.alarm(ALARM_ID_HEARTBIT, 300000, tmr.ALARM_AUTO, function()
    http.post('http://api.thingspeak.com/update?api_key=' .. THINGSPEAK_APIKEY .. '&field3=1', '', '');
  end)
end

main();

