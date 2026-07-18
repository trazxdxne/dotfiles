#!/usr/bin/env python3
import json
import os
from datetime import datetime, timedelta

def get_next_alarm():
    alarm_file = os.path.expanduser("~/.config/ags/alarms.json")
    if not os.path.exists(alarm_file):
        return None
    try:
        with open(alarm_file) as f:
            alarms = json.load(f)
    except Exception:
        return None
    
    now = datetime.now()
    next_time = None
    
    for a in alarms:
        if not a.get("enabled", False):
            continue
        try:
            h, m = map(int, a["time"].split(":"))
        except ValueError:
            continue
            
        candidate = now.replace(hour=h, minute=m, second=0, microsecond=0)
        
        days = a.get("days", "All")
        
        for i in range(8):
            test_date = candidate + timedelta(days=i)
            if test_date <= now:
                continue
                
            is_weekday = test_date.weekday() < 5
            if days == "Weekdays" and not is_weekday:
                continue
                
            if next_time is None or test_date < next_time:
                next_time = test_date
            break

    return next_time

next_time = get_next_alarm()
try:
    if next_time:
        ts = int(next_time.timestamp())
        with open("/sys/class/rtc/rtc0/wakealarm", "w") as f:
            f.write("0\n")
        with open("/sys/class/rtc/rtc0/wakealarm", "w") as f:
            f.write(f"{ts}\n")
    else:
        with open("/sys/class/rtc/rtc0/wakealarm", "w") as f:
            f.write("0\n")
except PermissionError:
    pass
