# Athrill VDEV プロトコル リファレンス

Athrill には、CPU 側から見える固定アドレス範囲へのメモリアクセスを、ホスト側のファイル(mmap)または UDP ソケット経由で外部プロセスに橋渡しする **VDEV（仮想デバイス）機構**が標準搭載されている。`device_config.txt` に `DEBUG_FUNC_ENABLE_VDEV 1` を設定するだけで有効になり、EV3RT 側のアプリ・カーネルには一切手を入れる必要がない。

対象: `toppers/ev3rt-athrill-v850e2m` + `toppers/athrill-target-v850e2m`（ARMv7-A 版 `toppers/ev3rt-athrill-ARMv7-A` でも同一アドレス体系であることを確認済み）。

## device_config.txt の設定

```
DEBUG_FUNC_ENABLE_VDEV		1
DEBUG_FUNC_VDEV_MMAP_TX	0x40000000
DEBUG_FUNC_VDEV_MMAP_RX	0x40010000
DEBUG_FUNC_VDEV_SIMSYNC_TYPE	MMAP
```

- `DEBUG_FUNC_VDEV_MMAP_TX` = ホスト側ファイル名は `athrill_mmap.bin`。**EV3RT アプリがモーター/LED 出力を書き込む側**（TX = CPU から見た送信）。
- `DEBUG_FUNC_VDEV_MMAP_RX` = ホスト側ファイル名は `unity_mmap.bin`。**外部プロセス（シム側）がセンサー値を書き込む側**（RX = CPU から見た受信）。
- ファイル名と TX/RX の対応がやや直感に反する（"unity_mmap.bin" が RX = センサー入力側）ので要注意。ファイルサイズは 8KB(`dd if=/dev/zero of=xxx.bin bs=1k count=8`)で作成しておく。
- UDP モード（`DEBUG_FUNC_VDEV_SIMSYNC_TYPE` を省略し `VDEV_TX/RX_PORTNO` を設定）も存在するが、今回は MMAP モードのみ検証。

## アドレス空間（CPU 側、`vdev.h` / `ev3_vdev_common.h` より）

```
VDEV_BASE          = 0x090F0000
VDEV_RX_DATA_BASE  = VDEV_BASE            size=0x1000  (シム→EV3RTアプリ)
VDEV_TX_DATA_BASE  = VDEV_BASE + 0x1000   size=0x1000  (EV3RTアプリ→シム)
VDEV_TX_FLAG_BASE  = VDEV_BASE + 0x2000   size=0x1000
```

## ホスト側ファイルのバイナリレイアウト

RX ファイル（`unity_mmap.bin`）:

| オフセット | 内容 |
|---|---|
| 0-3 | マジック `"ETRX"` |
| 4-7 | version (uint32, =1) |
| 8-15 | 予約 |
| 16-23 | `unity_simtime`（uint64, シム側の時刻） |
| 24-27 | ext_off (=512) |
| 28-31 | ext_size (=512) |
| 32-  | ボディ（下記センサーマップ、`32 + オフセット`） |

TX ファイル（`athrill_mmap.bin`）:

| オフセット | 内容 |
|---|---|
| 0-3 | マジック `"ETTX"` |
| 4-7 | version (uint32, =1) |
| 8-15 | `micon_simtime`（uint64, EV3RT/Athrill側の時刻） |
| 16-23 | `unity_simtime`（エコーバック） |
| 24-27 | ext_off (=512) |
| 28-31 | ext_size (=512) |
| 32-  | ボディ（下記モーターマップ、`32 + オフセット`） |

`micon_simtime`/`unity_simtime` の時刻交換フィールドが既に用意されているため、**Athrill側のクロックを外部シム（MuJoCo）の時刻に同期させるペーシング機構として転用できる見込み**（未実装、要検討）。

## ボディのレジスタマップ（バイトオフセットは `EV3_SENSOR_OFF_TYPE`/`EV3_MOTOR_OFF_TYPE` の値、実ファイルオフセットは `32 + この値`）

RX側（センサー、4byte/slot）:

| オフセット | 内容 |
|---|---|
| 0 (1byte) | ボタン（bit0-5 = LEFT/RIGHT/UP/DOWN/ENTER/BACK） |
| 4 | AMBIENT |
| 8 | COLOR |
| 12 | **REFLECT**（反射光、ライントレース用。ev3api の閾値判定は概ね 0-100 のスケール） |
| 16/20/24 | RGB_R/G/B |
| 28 | ANGLE (ジャイロ) |
| 32 | RATE |
| 36- | IR系（複数チャンネル） |
| 84 | **ULTRASONIC**（超音波距離、mm単位。`ev3_ultrasonic_sensor_get_distance()` は `/10` して cm 化） |
| 88 | ULTRASONIC_LISTEN |
| 92/96/100 | AXES_X/Y/Z |
| 104 | TEMP |
| 108 | **TOUCH_0**（タッチセンサー1個目。ev3api内部の「ポート順で数えた同種センサーの通し番号」に対応。ADC_RES=4095, 閾値は `val > 2047` でON） |
| 112/116 | BATTERY_CURRENT/VOLTAGE |
| 120 | **TOUCH_1**（タッチセンサー2個目） |
| 256- | モーター角度フィードバック ANGLE_A/B/C/D（4byteずつ） |

TX側（モーター/LED、オフセットはバイト単位）:

| オフセット | 内容 |
|---|---|
| 0 (1byte) | LED（bit0-3 = RED/GREEN/YELLOW/BLUE） |
| 4/8/12/16 | モーターPOWER_A/B/C/D |
| 20/24/28/32 | モーターSTOP_A/B/C/D |
| 36/40/44/48 | モーターRESET_ANGLE_A/B/C/D |
| 52 | GYRO_RESET |

## タッチセンサーのインデックス対応（ev3api 内部仕様）

`ev3api_sensor.c` の `get_sensor_index()` は、**ポート番号の小さい順に、同じセンサー種別が何個接続されているかを数えた通し番号**を `TOUCH_0`/`TOUCH_1` に割り当てる。例えば `touch_sensor = EV3_PORT_1`, `touch_sensor2 = EV3_PORT_2` の場合、`touch_sensor` → `TOUCH_0`、`touch_sensor2` → `TOUCH_1` となる（ポート番号順であって、`ev3_sensor_config()` の呼び出し順ではない点に注意）。

## 【要議論】VDEVレジスタマップの柔軟性の限界

実機EV3は、センサーポート4つ・モーターポート4つのどこに何を接続するかが自由で、
`ev3_sensor_config(port, type)` / `ev3_motor_config(port, type)` によってポートとデバイスの対応を
アプリ側が設定する（Lモーター/Mモーターの区別、NXT/RCX変換ケーブル経由のLED接続の区別なども含む）。

一方、上記のVDEVレジスタマップは REFLECT/ULTRASONIC/TOUCH_0/TOUCH_1 のような**センサー種別ごとに
個数固定のスロット**を持つ方式になっている。例えば超音波センサーを3個使う、あるいはカラーセンサーを
2個使うようなシステムの場合、現状のレジスタマップの再設計なしには対応できず、しかも「どのポートが
どれか」を実機のように柔軟に扱うことができない。

この点については以下のように整理している:

- これはAthrill（あるいはその上のev3api抽象化）側の設計の問題であり、我々はAthrillの利用者という
  立場なので、この柔軟性の限界を我々が解決すべき課題として引き取る必要はないかもしれない。
- 実際、EV3RT自身の `ev3api_sensor.c` の `get_sensor_index()`（ポート順で同種センサーを数えた
  通し番号を振る方式、下記参照）も、さほど柔軟ではなく一定の「割り切り」の上に成り立っている。
  つまりこの制約はAthrillのVDEV層固有のものというより、EV3RT/ev3apiの抽象化自体が既に持っている
  限界と見るべき。

今回の sample04-02（touch×2, color×1, ultrasonic×1）はこの限界の範囲内に収まる単純なケースだった。
将来、同種センサーを3個以上使う、あるいは実機と異なるポート構成にしたい等の要求が出た場合は、
まずこれが「Athrill/ev3apiの設計上の制約」であることを踏まえた上で、レジスタマップの拡張が必要か、
それとも要求自体を単純化できないか、を検討する。

**結論**: 現状のレジスタマップで対応できない構成のロボットを作った場合、レジスタマップの修正と
それに伴う対応部分の修正は不可避。ただし修正が必要なのは **Athrill本体（CPU命令セットシミュレーション
のコア）ではなく、ターゲット依存部**（`athrill-target-v850e2m` のVDEVレジスタ定義、`ev3_vdev_common.h`/
`vdev.h` 等）と **EV3RT側ドライバ層**（`uart_dri.c` 等のスロット参照箇所）に限定される見込み。
`VDEV_BASE` やRX/TXサイズ（現状 `0x1000`）、センサー種別ごとのスロット数はすべてこのターゲット依存部の
ヘッダで決め打ちされているため、そこを拡張し対応するドライバのアドレス参照も合わせて直す、という
一続きの改修になる。Athrillのコア自体への変更は不要な見込み。

## 検証に使ったスクリプト

`scripts/vdev_poke.py`（本リポジトリに同梱）。RX ファイルへのセンサー値書き込みと、TX ファイルからのモーター値読み出しを行う最小限の実験スクリプト。使用例は README を参照。
