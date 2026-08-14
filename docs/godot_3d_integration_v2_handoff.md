# Godot 3D統合 v2 完了時点 引き継ぎ資料

更新日: 2026-08-14

## この文書の位置付け

本書は、既存の`godot_blender_handoff.md`で計画していた3D化について、
実装・統合確認が完了した時点の差分をまとめた終盤資料である。

既存文書は「3D化へ着手する前の前提と計画」、本書は「実際に完成したStage 1の
構成、確定値、検証結果、既知の妥協点」を扱う。

次回は次の順で読む。

1. `godot_blender_handoff.md`
2. 本書
3. リポジトリの最新状態と関連ドキュメント

## リポジトリと確定基準点

- リポジトリ: <https://github.com/kuboaki/ev3rt-athrill-godot>
- ブランチ: `main`
- 確定コミット: `d609d633da54219dad1128a0242697084fdbce75`
- 確定タグ: `godot-3d-integration-v2`
- タグ注釈: `Verified Godot 3D integration with cargo and bumper outline`

旧基準点:

- `godot-3d-integration-v1`: Athrillと最初の3D完全シーケンスをUbuntuで確認
- `godot-3d-integration-v2`: Cargoと台形状バンパー判定を含む完全版

作業開始時の確認:

```bash
git pull --ff-only
git status --short
git log -3 --oneline
git tag --list 'godot-3d-*'
```

## 到達点

Ubuntu 24.04 ARM64上でAthrillとGodot 4.7.1を同時に動かし、次の状態遷移を
3D版で完走した。

```text
P_INIT
P_WAIT_FOR_LOADING
P_TRANSPORTING
P_WAIT_FOR_UNLOADING
P_RETURNING
P_ARRIVED
```

確認済みの流れ:

1. 初期状態ではCargo非表示
2. `L`キーでCargo表示、`TOUCH_1=4095`
3. `P_TRANSPORTING`でライントレース
4. 右向き超音波センサーで配達先壁を検出
5. `P_WAIT_FOR_UNLOADING`で停止
6. `L`キーでCargo非表示、`TOUCH_1=0`
7. `P_RETURNING`でライントレース
8. 台形状バンパーで車庫壁を検出
9. `P_ARRIVED`で停止

EV3RT/Athrill側の状態機械と制御ロジックは変更していない。Godot側は既存2D版と
同じ決定論的な差動二輪運動学を3D空間で実行する。

## 開発・実行環境

- Godot: `4.7.1.stable.official.a13da4feb`
- Blender: 5.1.1
- Blender単位: Metric、Unit Scale 1.0、Meters
- 統合実行: Parallels Desktop上のUbuntu 24.04 ARM64
- Mac: Blender/Godotの編集と単体確認

MacのGodotからUbuntuのAthrillへ直接接続する構成ではない。完成したリポジトリを
Ubuntuへpullし、Ubuntu上でGodotとAthrillを一緒に動かす。

## Godotの構成

- プロジェクト: `godot/`
- 2D基準シーン: `godot/Main.tscn`
- 3Dシーン: `godot/Main3D.tscn`
- 2Dスクリプト: `godot/vdev_monitor.gd`
- 3D走行: `godot/scripts/transporter_3d.gd`
- 3Dコース: `godot/scripts/course_line_3d.gd`
- 3D VDEV: `godot/scripts/vdev_adapter.gd`

プロジェクトのメインシーンは2D版のまま。3D版は`Main3D.tscn`を開いて`F6`で
実行する。`F5`は2Dメインシーンを実行する。

主要ノード:

```text
Main3D
├── Transporter
│   └── CargoAnchor
│       └── Cargo
├── DirectionalLight3D
├── Camera3D
├── CourseBase
├── CourseLine
├── VdevAdapter
├── DeliveryWall
├── UltrasonicRay
└── GarageWall
```

## Godotインポート情報

Godot 4の`<asset>.import`はUIDなどの重要なメタデータなのでGit管理する。
`.gitignore`から`*.import`は削除済み。

管理対象の例:

- `godot/assets/auto_transporter_godot.glb.import`
- `godot/assets/cuboid_godot.glb.import`
- `godot/assets/robot_top.png.import`
- `godot/icon.svg.import`

`godot/.godot/`はローカルキャッシュなのでGit管理しない。

`.import`を共有しないとMacとUbuntuで異なるUIDが生成され、次の警告が出ることが
ある。

```text
ext_resource, invalid UID ... using text path instead
```

## 走行体モデル

原資料:

- `studio_model/auto_transporter.blend`
- `studio_model/auto_transporter.io`
- `studio_model/auto_transporter.ldr`

Godot用:

- `studio_model/auto_transporter_godot.blend`
- `godot/assets/auto_transporter_godot.glb`

座標規約:

- Godot `+Y`: 上
- Godot `-Z`: 前方
- Godot `+X`: 右方
- 原点: 左右車輪中心の中点を通る地面上

概略寸法:

| 項目 | 値 |
|---|---:|
| 左右幅 | 約0.1851 m |
| 前後長 | 約0.2350 m |
| 高さ | 約0.1766 m |
| 車輪直径 | 約0.0559 m |
| 車輪幅 | 約0.0279 m |
| 車輪中心間距離 | 約0.1197 m |

Godot用Blenderモデルの確認値:

```text
bbox_min = (-0.0974, -0.1156, 0.0000)
bbox_max = ( 0.0876,  0.1195, 0.1766)
wheel centers = approximately ±0.0599 m
```

GLBに残したマーカー:

- `ColorSensorPoint`
- `ColorSensorOpticalCenter`
- `UltrasonicSensorOrigin`
- `UltrasonicDetectionFace`
- `BumperCompatibilityPoint`
- `BumperFrontExtreme`

Blender側の記録値:

```text
ColorSensorPoint          = (0.0560,  0.0800, 0.0064)
ColorSensorOpticalCenter  = (0.0559,  0.0760, 0.0064)
UltrasonicSensorOrigin    = (0.0403, -0.0556, 0.1316)
UltrasonicDetectionFace   = (0.0760, -0.0556, 0.1316)
BumperCompatibilityPoint  = (0.0000,  0.1100, 0.0250)
BumperFrontExtreme        = (-0.0020, 0.11947, 0.0250)
```

BlenderからGodotへエクスポートすると、前方はGodotの`-Z`になる。

## Cargoモデルと配置

原資料:

- `studio_model/cuboid.blend`
- `studio_model/cuboid.io`
- `studio_model/cuboid.ldr`

Godot用:

- `studio_model/cuboid_godot.blend`
- `godot/assets/cuboid_godot.glb`
- `godot/assets/cuboid_godot.glb.import`

元のLDraw単位へ`0.0004`を適用し、底面中央を`CargoRoot`の原点にした。

```text
bbox_min = (-0.02796, -0.01996, 0.00000)
bbox_max = ( 0.02796,  0.01996, 0.03992)
size     = ( 0.05592,  0.03992, 0.03992) m
```

最終配置は`Main3D.tscn`の`Transporter/CargoAnchor`。

```text
Position ≈ (-0.0680, 0.1414594, 0.0550)
Rotation ≈ (0°, -90°, 10°)
Scale    = (1, 1, 1)
```

Cargo自身はPosition/Rotationが0、Scaleが1。配置はCargoAnchorへ集約する。

`cargo_loaded`はCargo表示と`TOUCH_1`の共通状態。

- `false`: Cargo非表示、`TOUCH_1=0`
- `true`: Cargo表示、`TOUCH_1=4095`

## コース、走行、カメラ

コース:

| 項目 | 値 |
|---|---:|
| 用紙 | 0.841 x 0.594 m |
| ライン幅 | 0.026 m |
| 水平直線部 | 0.300 m |
| 垂直直線部 | 0.094 m |
| コーナー半径 | 0.145 m |

走行体初期値:

```gdscript
const INITIAL_POSITION := Vector3(0.08, 0.0, 0.248)
const INITIAL_YAW := PI * 0.5
const MOTOR_SPEED_SCALE := 0.003
const WHEEL_DISTANCE := 0.118
```

この配置でColorSensorPointが線上にあり、時計回りに走る。`power=20`は約
0.06m/sとしている。

カメラ:

```text
Position = (-0.48, 0.48, 0.62)
Rotation = (-34°, -38°, 0°)
FOV      = 42°
```

## 壁

### 配達先壁

- サイズ: 0.080 x 0.160 x 0.005 m
- Position: `(-0.040, 0.080, -0.129)`
- 本体: 淡い青緑、Alpha約35%
- 輪郭: `#2E6F78`、Grow 0.003 m

### 車庫壁

- サイズ: 0.120 x 0.170 x 0.005 m
- Position: `(0.330, 0.085, 0.085)`
- 本体: 淡い橙、Alpha約35%
- 輪郭: `#79562F`、Grow 0.003 m

透明表示には色のAlphaだけでなく、StandardMaterial3Dの
`Transparency=Alpha`が必要。

## センサー実装

### カラーセンサー

- `ColorSensorPoint`のワールドXZ位置を使用
- 線上: `REFLECT=5`
- 線外: `REFLECT=50`
- 判定半幅: `0.026 / 2` m

### 超音波センサー

- `UltrasonicSensorOrigin`から右向きの中心レイ1本
- 配達先壁の有限線分との交点距離をmmへ変換
- 非検出: `2550 mm`
- 可視化: 非検出は水色、検出は赤

実機は放射状だが、Stage 1では2D版に合わせて中心レイ1本としている。

### バンパー

実機バンパーは`3749.dat`と`3749.dat.001`をリンク軸として後退し、下端で最大
約17mm動く。現段階ではリンクアニメーションを省略し、前面が壁へ触れた時点で
`TOUCH_0`をONにする。

計測値:

- 最前端: 約13.01cm幅、前方119.47mm
- 少し後退した広い前面: 約16.27cm幅、前方98.3mm
- 機構全体幅: 約17.88cm

中央1点や13cmの単一線分では、斜め進入時にバンパー端が壁を越えた。このため
`BumperFrontExtreme`を基準に、前面を台形状の3線分として近似する。

```gdscript
const BUMPER_LEFT_SHOULDER_OFFSET := Vector3(-0.0811, 0.0, 0.02117)
const BUMPER_LEFT_NOSE_OFFSET := Vector3(-0.0650, 0.0, 0.0)
const BUMPER_RIGHT_NOSE_OFFSET := Vector3(0.0651, 0.0, 0.0)
const BUMPER_RIGHT_SHOULDER_OFFSET := Vector3(0.0816, 0.0, 0.02117)
```

境界は「左肩→左前端→右前端→右肩」。各線分と有限長の車庫壁との最短距離を
求める。これにより斜め進入でもそれらしく停止する。

将来は前面接触をリンクアニメーション開始条件にし、約17mm後退して赤い
プランジャーが押された時点を`TOUCH_0`にできる。

## VDEVと時間モデル

MMAP:

- `unity_mmap.bin`: GodotからEV3RTへのセンサー入力
- `athrill_mmap.bin`: EV3RTからGodotへのモーター出力

入力:

- `REFLECT`
- `ULTRASONIC`（mm）
- `TOUCH_0`
- `TOUCH_1`

出力:

- `POWER_A`: 左モーター
- `POWER_C`: 右モーター

書き込み後は`FileAccess.flush()`が必要。詳細は`docs/vdev_protocol.md`。

- EV3RT制御周期: 50 ms
- Godot更新: `_physics_process()`
- VDEV交換指定: 10 ms。実際は固定物理フレームごとに最新値を交換

描画負荷で結果が変わらないよう、走行・センサー・VDEVは固定物理更新で処理する。

## 操作

- `L`: Cargo搭載・荷下ろし
- `Space`: Godot内の走行体位置と姿勢だけを初期化

SpaceではAthrillのEV3RT状態機械は初期化されない。完全にやり直す場合はAthrillを
停止し、MMAPを再初期化して再起動する。

## Ubuntuでの統合実行

正規プロジェクト:

```text
~/Projects/ev3rt_godot/ev3rt-athrill-godot/godot
```

次は旧2Dコピーなので正規版ではない。

```text
~/Projects/ev3rt_godot/auto-transporter-godot
```

Athrill起動例:

```bash
cd ~/Projects/ev3rt_godot/ev3rt-athrill-godot
ATHRILL_TIMEOUT_CLOCKS=60000000000 \
  ./scripts/run_sample04_stm.sh
```

Godotでは`Main3D.tscn`を開いて`F6`。Athrillが`P_WAIT_FOR_LOADING`になったら
ゲーム画面へフォーカスを移して`L`を押す。

## 既知の問題

### 埋め込みゲーム画面のキー入力

あるMacのGodotセッションでは、埋め込みゲーム画面の「入力」をオンにしても
キーイベントが届かなかった。同一コミットは別のMacとUbuntuでLキーを正常取得。
コードではなく、エディターセッションまたは入力キャプチャ状態に限定された現象と
判断した。再起動または埋め込みを無効にした別ウィンドウ実行で切り分ける。

### 実行中のマテリアル編集

Remote Inspectorで一時マテリアルを作ると、次のエラーが出ることがある。

```text
Resource file not found: res://::StandardMaterial3D_...
```

マテリアルは実行停止中のローカルシーンで編集する。

### Godotの実行停止

Linuxではプロセス名の大文字小文字に注意する。

```bash
pgrep -a Godot
pkill Godot
```

## 現段階の妥協点

- 剛体、摩擦、慣性、車輪接触物理は未導入
- 車輪回転の表示は未実装
- 超音波センサーは円錐ではなく中心レイ1本
- バンパーリンクの約17mm後退は未実装
- Cargoの積載・荷下ろしアニメーションは未実装
- 壁は表示用BoxMeshと判定用有限線分

## 主要コミット

| コミット | 内容 |
|---|---|
| `4fbf3bd` | Godot用走行体GLBとBlenderモデル |
| `56237b2` | 最初のGodot 3Dコースシーン |
| `9ed6412` | 3DセンサーとVDEVを接続 |
| `6ba8a81` | GodotインポートメタデータをGit管理 |
| `c48da95` | 3Dカメラ構図を調整 |
| `c9e881e` | 半透明壁と輪郭を調整 |
| `9b431a1` | Godot用Cuboidモデルを追加 |
| `913c54e` | Cargo表示と入力診断を追加 |
| `94b9647` | 一時入力診断を削除 |
| `9a22d53` | Cargoを荷台上へ再配置 |
| `d609d63` | バンパー外形全体で車庫接触を判定 |

## 次回候補

優先度は未決定。

1. バンパーリンクの後退アニメーションとプランジャー押下
2. Cargoの積載・荷下ろしアニメーション
3. 車輪回転の表示
4. センサー判定領域の可視化改善
5. カメラ・壁・背景の最終デザイン
6. 必要性を評価したうえでの剛体物理導入

## 次回セッションへの依頼文例

> `ev3rt-athrill-godot`のGodot 3D対応を、タグ
> `godot-3d-integration-v2`（コミット`d609d63`）から継続します。
> Athrill側の制御ロジックは変更せず、Godot側は決定論的な差動二輪運動学、
> VDEV、4センサー、Cargo表示、台形状バンパー判定まで実装・統合確認済みです。
> 既存の`godot_blender_handoff.md`と本書を確認し、2D版と完全シーケンスを
> 壊さないよう、一手順ずつ進めてください。
