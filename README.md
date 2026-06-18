# NotSleep

MacBookのスリープ有効化/無効化を切り替えるmacOSアプリです。

## 機能

- SwiftUI標準Toggleでスリープ有効/無効を切り替え
- メニューバーのSF Symbolsアイコンをクリックして同じ切り替え
- スリープ有効化中は月アイコン、スリープ無効化中は太陽アイコン
- 画面を閉じたときのスリープ抑制に必要な`pmset disablesleep`を使用
- 初回起動時にだけ管理者認証を行い、以後は認証なしで切り替え
- 起動中も現在のシステム設定を定期的に取得してUIへ反映
- ウィンドウを閉じてもメニューバー常駐は継続し、Dockからは非表示

## 操作

- メニューバーアイコンを左クリック: スリープ有効/無効を切り替え
- メニューバーアイコンを右クリック: ウィンドウ表示/終了メニューを表示

## ビルド

```sh
make app
```

生成されるアプリ:

```text
.build/release/NotSleep.app
```

起動:

```sh
make run
```

## 注意

初回起動時に、`pmset disablesleep`を認証なしで実行するための最小ヘルパーをインストールします。管理者認証はこの初回セットアップ時のみ必要です。

インストールされるファイル:

```text
/Library/PrivilegedHelperTools/local.notsleep.pmset-helper
/etc/sudoers.d/local-notsleep
```

元に戻す場合はアプリでオンに戻すか、次のコマンドを実行してください。

```sh
sudo pmset -a disablesleep 0
```
