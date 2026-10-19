# Wire protocol test vectors

Shared by `GarminyCoreTests` (Swift) and `tests/CompanionTests.mc` (Monkey C). Each frame is hex; every frame is at most 20 bytes.

- HEARTBEAT, msgId 7
  - `090701`
- HELLO version 1, msgId 0
  - `41000101`
- ACK alert 5, msgId 3
  - `42030105`
- OPEN alert 5, msgId 6
  - `44060105`
- HELLO_REPLY version 1, Mac time 1760000000, msgId 1
  - `0101010168e77800`
- BUZZ alert 2, msgId 4
  - `04040102`
- SNAPSHOT_END, msgId 8
  - `080801`
- LOCATION Montreal 45.50, -73.57, msgId 9
  - `06090111c6e343`
- SETTINGS changedAt 1760000000, cards 0x01FF, interval 10, cities 0/33/9, units 0, backlight 0, companion 1, msgId 10
  - `070a0168e7780001ff0a002109000001`
- WEATHER observed 1760000000, now 12C cond 1, today 15/6 cond 3, tomorrow 9/2 cond 3, hourly base 1759998600, chances 0,10,20,30,40,50,60,70,80,90,100,255, msgId 11
  - `050b0268e778000c010f060309020368e7728800`
  - `050b120a141e28323c46505a64ff`
- ALERTS total 1: id 1 needs-you buzz label "garminy" detail "Permission: Bash", msgId 12
  - `030c020101010001076761726d696e7910506572`
  - `030c126d697373696f6e3a2042617368`
- ALERTS total 1: id 2 done, openable, no buzz, label "garminy" detail "4m", msgId 14
  - `030e010101020202076761726d696e7902346d`
- SESSIONS 3 shown, 0 hidden: needs-you 0m "garminy", working 12m "api-svc", done 3m "website", msgId 13
  - `020d030300010000076761726d696e7900000c07`
  - `020d136170692d73766302000307776562736974`
  - `020d2365`

## Layout

Frame: `[type][msgId][part<<4 | total]` + up to 17 payload bytes. Parts are numbered from 0, and `total` is 1–15. Integers are big-endian. Strings are a length byte followed by UTF-8.

| Type | Payload |
|---|---|
| `01` HELLO_REPLY | version u8, Mac time u32 |
| `02` SESSIONS | shown u8, hidden u8, then per session: state u8, minutes in state u16, label (≤16 bytes) |
| `03` ALERTS | total u8, shown u8 (≤5), then per alert: id u8, kind u8, flags u8 (bit 0 buzz, bit 1 openable), label (≤24), detail (≤20) |
| `04` BUZZ | alert id u8 |
| `05` WEATHER | observed u32, now temp i8, now condition u8, today hi i8 lo i8 condition u8, tomorrow hi i8 lo i8 condition u8, hourly base u32, 12 × chance u8 (255 = unknown) |
| `06` LOCATION | lat i16 ×100, lon i16 ×100 |
| `07`/`43` SETTINGS | changedAt u32, cards u16, interval u8, city1–3 i8, units u8, backlight u8, companion u8 |
| `08` SNAPSHOT_END, `09` HEARTBEAT | none |
| `41` HELLO | version u8 |
| `42` ACK | alert id u8 |
| `44` OPEN | alert id u8 (acknowledge, then open the session on the Mac) |

- **Session state:** 0 working, 1 needs you, 2 done, 3 error.
- **Alert kind:** 0 needs you, 1 failed, 2 done.
- **Card bits:** bit 0 Agents, 1 Fortune, 2 Quote, 3 Umbrella, 4 Weather, 5 Daylight, 6 Moon, 7 World clock, 8 On this day.
- **Temperatures:** °C. **Conditions:** Garmin `Weather.CONDITION_*` values.
