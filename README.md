# EV3RT + Athrill + Godot

EV3RTアプリケーションをAthrill上で実行し、Godotの走行体シミュレータと
VDEV MMAPでセンサー値・モーター値を交換するための統合プロジェクト。

## 現在の到達点

Ubuntu 24.04 ARM64上で以下を確認済み。

- Athrill v850e2mターゲットをARM64ネイティブビルド
- GNUV850 v14.01（GCC 4.9）をARM64ホスト向けにビルド
- EV3RT sample03をAthrill上で実行
- Godot 4.7.1 ARM64版からVDEV MMAPへアクセス
- 反射光値に応じたEV3RT Cコードのモーター出力変更を連続動作で確認

確認結果:

    REFLECT=5  -> POWER_A=0,  POWER_C=20
    REFLECT=50 -> POWER_A=20, POWER_C=0

## 依存リポジトリと固定コミット

- athrill-target-v850e2m
  - dff01d79d13a4625dab6c86e82710e7eaebed4ef
- ev3rt-athrill-v850e2m
  - eaa870b4e68413649d50e1b6d09d832b7de3af78
- athrill-gcc-v850e2m
  - 181a8e08fbbe452311c577057078fe7cc5a6a678
- ev3rt-athrill-mujoco（VDEV資料の出典）
  - ff15e101917ed44ed72ee45d78b5d1068b542e17

## ディレクトリ

- patches/
  - EV3RTのRuby 3対応パッチ
- toolchain/
  - Ubuntu ARM64用GNUV850 v14.01ビルドスクリプト
- workspace/sample03/
  - VDEV双方向通信の確認に使ったEV3RTアプリケーション
- godot/
  - Godot側のVDEVモニター
- docs/
  - 構築手順と設計資料
- scripts/
  - ビルド・実行補助スクリプト

## GNUV850ツールチェーンの構築

Ubuntu 24.04 ARM64上で、GNUV850 v14.01（GCC 4.9.2）を
クリーン状態から構築できることを確認済み。

    ./toolchain/build_gcc_rh850_arm64.sh

スクリプトはTOPPERSのv1.1リリースから改修済みBinutils 2.24を取得し、
GCC 4.9.2とNewlib 2.1.0をC言語用に構築する。生成先は次のとおり。

    toolchain/work/install/v850-elf-gcc-linux-arm64

Parallelsの2コアARM64 VMでの初回構築時間は約22分。
`toolchain/work/`はGit管理対象外である。

## Athrillとsample03のビルド

AthrillをUbuntu ARM64上でビルドする。

    ./scripts/build_athrill.sh

このスクリプトはARM64でEOFを正しく検出するため、
Athrillコアの`file_getline()`で`fgetc()`の戻り値を`int`として保持する
パッチを適用する。また、EV3RT公式手順に基づき`timer32=true`および
`etrobo_optimize=true`を有効にする。MMAP VDEVを使うため
`vdev_disable=true`は指定しない。

EV3RTのsample03は次でビルドする。

    ./scripts/build_sample03.sh

生成された`asp`は依存リポジトリ側の
`sdk/workspace/sample03/asp`へ配置される。

## sample03の起動

MMAPファイルを初期化してAthrillを起動する。

    ./scripts/run_sample03.sh

既定のタイムアウトクロックは`3000000000`。変更する場合は次のようにする。

    ATHRILL_TIMEOUT_CLOCKS=300000000 ./scripts/run_sample03.sh

Athrillはタイムアウト終了時にも終了コード`1`を返す。

## 荷物運搬ステートマシン

`uml_seminar_ev3/`はEV3RT SDK内で標準の`workspace/`と並べて使う
別ワークスペースである。`sample04-01-stm`は次のセンサーを使用する。

- ポート1: 前方バンパー用タッチセンサー
- ポート2: 荷物搭載確認用タッチセンサー
- ポート3: ライントレース用カラーセンサー
- ポート4: 到着地点検出用超音波センサー

元の演習ソースでは初期状態`P_INIT`の処理が欠落していたため、
移植版では`porter_init()`を実行して`P_WAIT_FOR_LOADING`へ遷移する処理を
追加している。

ビルドと起動は次のとおり。

    ./scripts/build_sample04_stm.sh
    ./scripts/run_sample04_stm.sh

## 実時間同期

`workspace/sample03/device_config_mmap_sync.txt` では次を有効化している。

    DEBUG_FUNC_ENABLE_SKIP_CLOCK 1
    DEBUG_FUNC_ENABLE_SYNC_TIME  1

2コアのParallels VMでは、Athrillを次のように実行すると安定する。

    taskset -c 1 nice -n 15 athrill2 ...

## GodotとMMAP

Godotで `unity_mmap.bin` を更新した後は、Athrillの共有マッピングへ
確実に反映させるため `FileAccess.flush()` を呼び出す。

Godotエディターを強制終了した場合、実行シーンだけが孤児プロセスとして
残る場合がある。異常時は次で確認する。

    pgrep -a -f Godot_v4.7.1

## 制御コードの方針

最終的な制御・状態機械は自動生成したCコードとしてEV3RT/Athrill上で動かす。
GodotのGDScriptは、走行体、ワールド、センサー表現、VDEVアダプターのみを担当する。

## 次の作業

- Godot上に簡易差動二輪走行体を作成
- POWER_A / POWER_Cを位置と姿勢へ反映
- コースから反射光値を生成
- sample04-01-stmまたは自動生成Cコードへ差し替え
- Unityリソースを参考に3D走行体とワールドを再構築
