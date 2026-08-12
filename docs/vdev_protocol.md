# Athrill VDEVプロトコル リファレンス

Athrillには、CPU側から見える固定アドレス範囲へのメモリアクセスを、
ホスト側の共有ファイル（mmap）またはUDPソケット経由で外部プロセスへ
橋渡しするVDEV（仮想デバイス）機構がある。

このプロジェクトではMMAPモードを使用し、EV3RT/AthrillとGodotの間で
センサー入力とモーター出力を交換する。EV3RTアプリケーションは通常の
EV3 APIを使用し、VDEV固有の処理を持たない。

対象リポジトリ:

- `toppers/ev3rt-athrill-v850e2m`
- `toppers/athrill-target-v850e2m`

ARMv7-A版`ev3rt-athrill-ARMv7-A`でも同じアドレス体系が使われていることを
確認している。

## MMAPモードの設定

`device_config_mmap_sync.txt`では次を設定する。

```text
DEBUG_FUNC_ENABLE_VDEV            1
DEBUG_FUNC_VDEV_MMAP_TX           0x40000000
DEBUG_FUNC_VDEV_MMAP_RX           0x40010000
DEBUG_FUNC_VDEV_SIMSYNC_TYPE      MMAP
DEBUG_FUNC_ENABLE_SKIP_CLOCK      1
DEBUG_FUNC_ENABLE_SYNC_TIME       1
```

- `DEBUG_FUNC_VDEV_MMAP_TX`
  - ホスト側ファイルは`athrill_mmap.bin`
  - EV3RTアプリケーションからシミュレーターへ送るモーター・LED出力
- `DEBUG_FUNC_VDEV_MMAP_RX`
  - ホスト側ファイルは`unity_mmap.bin`
  - シミュレーターからEV3RTアプリケーションへ送るセンサー入力
- `DEBUG_FUNC_VDEV_SIMSYNC_TYPE=MMAP`
  - VDEVの入出力に共有ファイルを使用する

TX/RXはCPU側から見た方向である。`unity_mmap.bin`という名前のファイルが
RX、すなわちGodotからEV3RTへ渡す入力側である点に注意する。

各ファイルは8 KiBで作成する。

```bash
dd if=/dev/zero of=athrill_mmap.bin bs=1K count=8
dd if=/dev/zero of=unity_mmap.bin bs=1K count=8
```

起動スクリプトはファイル作成と初期化を自動的に行う。

UDPモードも存在するが、このプロジェクトではMMAPモードだけを検証している。

## データの流れ

| 方向 | ホスト側ファイル | 内容 |
|---|---|---|
| Godot → Athrill/EV3RT | `unity_mmap.bin` | 反射光、超音波、タッチなどのセンサー入力 |
| Athrill/EV3RT → Godot | `athrill_mmap.bin` | モーターpower、停止、LEDなどの出力 |

Godotはワールドと走行体からセンサー値を計算してRXファイルへ書き込む。
EV3RTアプリケーションはEV3 APIを通じてその値を読み、制御結果をTX側へ
書き込む。GodotはTXファイルから左右モーターのpower値を読み、走行体の
位置と姿勢を更新する。

## CPU側のVDEVアドレス空間

`vdev.h`で次の領域が定義されている。

```text
VDEV_BASE          = 0x090F0000
VDEV_RX_DATA_BASE  = VDEV_BASE            size=0x1000
VDEV_TX_DATA_BASE  = VDEV_BASE + 0x1000   size=0x1000
VDEV_TX_FLAG_BASE  = VDEV_BASE + 0x2000   size=0x1000
```

- RX領域: シミュレーターからEV3RTアプリケーションへの入力
- TX領域: EV3RTアプリケーションからシミュレーターへの出力
- TXフラグ領域: VDEV送信制御用

CPU側のRX/TXアクセスでは、ホスト側ファイルの32バイトヘッダーを除いた
ボディ部分がレジスター空間として見える。

## ホスト側ファイルのバイナリレイアウト

整数値はリトルエンディアンで格納する。

### RXファイル: `unity_mmap.bin`

| ファイルオフセット | 型 | 内容 |
|---:|---|---|
| 0～3 | 4 bytes | マジック`ETRX` |
| 4～7 | `uint32` | version（1） |
| 8～15 | 8 bytes | 予約領域 |
| 16～23 | `uint64` | `unity_simtime` |
| 24～27 | `uint32` | `ext_off`（512） |
| 28～31 | `uint32` | `ext_size`（512） |
| 32～ | body | センサー入力 |

### TXファイル: `athrill_mmap.bin`

| ファイルオフセット | 型 | 内容 |
|---:|---|---|
| 0～3 | 4 bytes | マジック`ETTX` |
| 4～7 | `uint32` | version（1） |
| 8～15 | `uint64` | `micon_simtime` |
| 16～23 | `uint64` | `unity_simtime`のエコーバック |
| 24～27 | `uint32` | `ext_off`（512） |
| 28～31 | `uint32` | `ext_size`（512） |
| 32～ | body | モーター・LED出力 |

実ファイル上のレジスター位置は次の式で求める。

```text
file_offset = 32 + body_offset
```

## シミュレーション時刻

`micon_simtime`と`unity_simtime`はマイクロ秒単位で扱われる。
AthrillのMMAP VDEV処理は、RXヘッダーの`unity_simtime`を読み、CPU周波数を
掛けて外部シミュレーター側の目標クロックへ変換する。

現在のGodot実装は`unity_simtime=0`を書き込んでいる。この場合、外部時刻を
基準にAthrillを進める正式なシミュレーション時刻同期は行われない。

一方、現在の起動設定では次を有効にしており、Athrillのスキップクロック時の
実時間ペーシングは動作する。

```text
DEBUG_FUNC_ENABLE_SKIP_CLOCK 1
DEBUG_FUNC_ENABLE_SYNC_TIME  1
```

したがって、次の2つを区別する必要がある。

- Athrill単体の実時間ペーシング: 現在有効
- Godotのシミュレーション時刻を基準とする同期: 未実装

## RXボディのセンサーレジスタ

各センサースロットは原則4バイトである。次表のオフセットはbody先頭からの
バイトオフセットであり、実ファイル位置は`32 + オフセット`となる。

| bodyオフセット | 内容 |
|---:|---|
| 0（1 byte） | ボタン。bit 0～5はLEFT/RIGHT/UP/DOWN/ENTER/BACK |
| 4 | AMBIENT |
| 8 | COLOR |
| 12 | REFLECT。反射光、概ね0～100のスケール |
| 16 / 20 / 24 | RGB_R / RGB_G / RGB_B |
| 28 | ANGLE（ジャイロ） |
| 32 | RATE |
| 36～ | IR関連 |
| 84 | ULTRASONIC。mm単位 |
| 88 | ULTRASONIC_LISTEN |
| 92 / 96 / 100 | AXES_X / AXES_Y / AXES_Z |
| 104 | TEMP |
| 108 | TOUCH_0 |
| 112 / 116 | BATTERY_CURRENT / BATTERY_VOLTAGE |
| 120 | TOUCH_1 |
| 256～ | モーター角度フィードバックANGLE_A/B/C/D |

`ev3_ultrasonic_sensor_get_distance()`はULTRASONIC値を10で割り、cmとして返す。

タッチセンサーはADC値として扱われ、`4095`をON、`0`をOFFとして使用する。
EV3RT側では概ね`value > 2047`で押下と判定される。

## sample04-01-stmで使用するRX入力

| VDEV入力 | EV3ポート | Godotでの値 | 用途 |
|---|---|---|---|
| REFLECT | ポート3 | ライン上`5`、ライン外`50` | ライントレース |
| ULTRASONIC | ポート4 | 右側の配達先壁までの距離（mm） | 配達先到着検出 |
| TOUCH_0 | ポート1 | OFF`0`、ON`4095` | 前方バンパーによる車庫壁検出 |
| TOUCH_1 | ポート2 | OFF`0`、ON`4095` | 左側荷台の荷物搭載確認 |

Godotの`L`キーは`TOUCH_1`を切り替える。

## TXボディの出力レジスタ

次表のオフセットはbody先頭からのバイトオフセットである。

| bodyオフセット | 内容 |
|---:|---|
| 0（1 byte） | LED。bit 0～3はRED/GREEN/YELLOW/BLUE |
| 4 / 8 / 12 / 16 | POWER_A / POWER_B / POWER_C / POWER_D |
| 20 / 24 / 28 / 32 | STOP_A / STOP_B / STOP_C / STOP_D |
| 36 / 40 / 44 / 48 | RESET_ANGLE_A / B / C / D |
| 52 | GYRO_RESET |

`sample04-01-stm`ではポートAを左モーター、ポートCを右モーターとして使う。

```text
REFLECT=5  -> POWER_A=0,  POWER_C=20
REFLECT=50 -> POWER_A=20, POWER_C=0
```

配達先と車庫で停止したときは次を確認している。

```text
POWER_A=0
POWER_C=0
```

## タッチセンサーのインデックス対応

`ev3api_sensor.c`の`get_sensor_index()`は、ポート番号の小さい順に同じ種類の
センサーが何個接続されているかを数え、その通し番号をVDEVスロットへ対応させる。

`sample04-01-stm`では次の対応になる。

```text
EV3_PORT_1 -> TOUCH_0 -> 前方バンパー
EV3_PORT_2 -> TOUCH_1 -> 荷台の荷物搭載確認
```

これは`ev3_sensor_config()`の呼び出し順ではなく、ポート番号順である。

## Godot実装上の注意

### 共有ファイルの反映

Godotは`unity_mmap.bin`へ書き込んだ後、`FileAccess.flush()`を呼び出す。
これにより変更をAthrillの共有マッピングへ確実に反映する。

同じファイルを別のGodot実行シーンが同時に書き込むと、入力値が競合する。
孤児プロセスも含め、VDEVファイルの書き手は1プロセスだけにする。

```bash
pgrep -a -f Godot_v4.7.1
```

### 更新周期

EV3RTの周期ハンドラは50 ms周期である。Godot側のVDEV交換周期を同じ50 msに
固定すると、両者の位相によって短時間のセンサー変化を取りこぼす可能性がある。

現在のGodot実装では10 msを交換周期として指定している。実際には固定物理
フレームごとに最新値を交換する。

### 固定物理周期

走行体の位置・姿勢は`_process()`ではなく`_physics_process()`で更新する。
可変描画周期で更新すると、ファイルI/Oなどによって`delta`が大きくなった際に
カラーセンサーが1ステップでラインを横断し、進行方向が反転することがあった。

固定物理周期への変更後、角丸矩形コースの継続周回と完全運搬シーケンスを
確認している。

## EV3 LCDコンソール出力との関係

EV3 LCD文字列はVDEV MMAPを通していない。

Athrill向け`ev3_lcd_draw_string()`の実装が文字列を標準出力へ転送する。
同じLCD行に同じ文字列が繰り返された場合は、EV3APIエミュレーション層で
重複出力を抑止する。

したがって、次の経路は独立している。

- センサー・モーター: VDEV MMAP
- LCD状態名: Athrillプロセスの標準出力

## VDEVレジスターマップの制約

実機EV3では、4つのセンサーポートと4つのモーターポートへ接続する機器を
アプリケーションが設定できる。

一方、現在のVDEVレジスターマップはREFLECT、ULTRASONIC、TOUCH_0、
TOUCH_1のように、センサー種別ごとに固定数のスロットを持つ。

このため、たとえば超音波センサーを3個、カラーセンサーを2個使う構成は、
現状のレジスターマップのままでは扱えない。

`sample04-01-stm`の構成（touch×2、color×1、ultrasonic×1）は現在の範囲に
収まっている。

対応できない構成が必要になった場合、次を一続きで変更する必要がある。

- `athrill-target-v850e2m`のVDEVレジスター定義
- `ev3_vdev_common.h`、`vdev.h`などのターゲット依存ヘッダー
- `uart_dri.c`などEV3RT側ドライバーの参照処理

CPU命令セットシミュレーションを行うAthrillコア自体の変更は不要と見込まれる。

## 検証用スクリプト

`scripts/vdev_poke.py`はRXファイルへのセンサー値書き込みと、TXファイルからの
モーター値読み出しを行う最小の診断ツールである。

例:

```bash
python3 scripts/vdev_poke.py \
  read_tx \
  ../ev3rt-athrill-v850e2m/sdk/uml_seminar_ev3/sample04-01-stm/athrill_mmap.bin
```

出力例:

```text
TX header: magic=b'ETTX' version=1 micon_simtime=137680320 unity_simtime=0
POWER_A(left)=0 POWER_C(right)=0
```

## 関連文書

- [`README.md`](../README.md)
- [`physical_model.md`](physical_model.md)
