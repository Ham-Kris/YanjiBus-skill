#!/bin/bash
# 延吉公交实时查询工具
# 用法: ./yanji-bus.sh <线路号> [子线路号]
# 例如: ./yanji-bus.sh 3 3

LINE="${1:?用法: ./yanji-bus.sh <线路号> [子线路号]}"
SUBLINE="${2:-1}"
UA="Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.69(0x1800452d) NetType/WIFI Language/en"
REFERER="http://bus.yanjibus.com:8082/html/bus-route-${LINE}-${SUBLINE}.html"

# 获取实时车辆数据
BUS_DATA=$(curl -s \
  -H "User-Agent: $UA" \
  -H "Referer: $REFERER" \
  -H "X-Requested-With: XMLHttpRequest" \
  "http://bus.yanjibus.com:8082/html/line_data_json_add/line_data_${LINE}_${SUBLINE}.json?r=0.$(date +%s)")

# 获取线路页面（站点信息）
ROUTE_HTML=$(curl -s \
  -H "User-Agent: $UA" \
  "http://bus.yanjibus.com:8082/html/bus-route-${LINE}-${SUBLINE}.html")

# 用 python3 解析所有数据
python3 -c "
import sys, json, re

html = sys.stdin.read()

# 提取站点名称
up_stations = re.findall(r'id=\"bus-up-(\d+)\".*?bus-line-name\">([^<]+)', html)
down_stations = re.findall(r'id=\"bus-down-(\d+)\".*?bus-line-name\">([^<]+)', html)

print('=== 站点信息 ===')
if up_stations:
    up_first = up_stations[0][1]
    up_last = up_stations[-1][1]
    print(f'【上行站点】({up_first} → {up_last})')
    for num, name in up_stations:
        print(f'  {num}. {name}')
print()
if down_stations:
    down_first = down_stations[0][1]
    down_last = down_stations[-1][1]
    print(f'【下行站点】({down_first} → {down_last})')
    for num, name in down_stations:
        print(f'  {num}. {name}')

# 解析实时数据
bus_json = '''$BUS_DATA'''
print()
print('=== 实时车辆数据 ===')
try:
    data = json.loads(bus_json)
    busdata_str = data.get('busdata', '')
    busdata_str = busdata_str.replace(\"'\", '\"')
    busdata = json.loads(busdata_str)

    up_buses = busdata.get('up', {}).get('busarray', [])
    down_buses = busdata.get('down', {}).get('busarray', [])

    # 建立站名映射
    up_map = {num: name for num, name in up_stations}
    down_map = {num: name for num, name in down_stations}

    up_dir = ''
    down_dir = ''
    if up_stations:
        up_dir = f'({up_stations[0][1]} → {up_stations[-1][1]})'
    if down_stations:
        down_dir = f'({down_stations[0][1]} → {down_stations[-1][1]})'

    if up_buses:
        print(f'【上行在途车辆: {len(up_buses)}辆】{up_dir}')
        for b in up_buses:
            snum = str(b['stationnum'])
            sname = up_map.get(snum, '未知站点')
            print(f'  -> 第{snum}站 [{sname}] 附近 | 速度:{b[\"speed\"]}km/h | 时间:{b[\"time\"]}')
    else:
        print(f'【上行: 暂无在途车辆】{up_dir}')

    print()

    if down_buses:
        print(f'【下行在途车辆: {len(down_buses)}辆】{down_dir}')
        for b in down_buses:
            snum = str(b['stationnum'])
            sname = down_map.get(snum, '未知站点')
            print(f'  -> 第{snum}站 [{sname}] 附近 | 速度:{b[\"speed\"]}km/h | 时间:{b[\"time\"]}')
    else:
        print(f'【下行: 暂无在途车辆】{down_dir}')
except Exception as e:
    print(f'解析失败: {e}')
" <<< "$ROUTE_HTML"
