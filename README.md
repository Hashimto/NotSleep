# NotSleep

## 日本語

MacBookのスリープ有効化/無効化を切り替えるmacOSアプリです。

### 機能

- SwiftUI標準Toggleでスリープ有効/無効を切り替え
- メニューバーのSF Symbolsアイコンをクリックして同じ切り替え
- スリープ有効化中は月アイコン、スリープ無効化中は太陽アイコン
- 画面を閉じたときのスリープ抑制に必要な`pmset disablesleep`を使用
- 初回起動時にだけ管理者認証を行い、以後は認証なしで切り替え
- 起動中も現在のシステム設定を定期的に取得してUIへ反映
- ウィンドウを閉じてもメニューバー常駐は継続し、Dockからは非表示

### 操作

- メニューバーアイコンを左クリック: スリープ有効/無効を切り替え
- メニューバーアイコンを右クリック: ウィンドウ表示/終了メニューを表示

### ビルド

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

### リリース用DMG

GitHub Actionsで`main`へのpushごとにリリース用DMGを自動生成します。生成された`NotSleep.dmg`は、その実行のArtifactsからダウンロードできます。

配布用DMGはGatekeeperでブロックされないように、Developer ID署名とApple notarizationを行います。Actionsを動かす前に、GitHubリポジトリのSecretsに次の値を設定してください。

```text
DEVELOPER_ID_CERTIFICATE_BASE64
DEVELOPER_ID_CERTIFICATE_PASSWORD
DEVELOPER_ID_APPLICATION
KEYCHAIN_PASSWORD
APPLE_ID
APPLE_TEAM_ID
APPLE_APP_SPECIFIC_PASSWORD
```

`DEVELOPER_ID_APPLICATION`は、キーチェーンに表示される`Developer ID Application: ... (TEAMID)`形式の証明書名です。

`v1.0.0`のような`v*`タグをpushした場合は、DMGを添付したGitHub Releaseも自動作成されます。

```sh
git tag v1.0.0
git push origin v1.0.0
```

### 注意

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

### AIの使用について

このアプリの設計、実装、README作成にはAI支援を使用しています。最終的な内容と動作確認は開発者が行っています。

### ライセンス

このプロジェクトはMIT Licenseで公開されています。詳細は[LICENSE](LICENSE)を参照してください。

## English

NotSleep is a macOS app for toggling sleep on and off on a MacBook.

### Features

- Toggle sleep on/off with the standard SwiftUI Toggle
- Toggle the same setting from a menu bar SF Symbols icon
- Shows a moon icon while sleep is enabled, and a sun icon while sleep is disabled
- Uses `pmset disablesleep` to prevent sleep when the MacBook lid is closed
- Requests administrator authentication only during the first setup
- Periodically reads the current system setting while running and reflects it in the UI
- Keeps running in the menu bar when the window is closed, while hiding from the Dock

### Controls

- Left-click the menu bar icon: toggle sleep on/off
- Right-click the menu bar icon: show the window/quit menu

### Build

```sh
make app
```

Generated app:

```text
.build/release/NotSleep.app
```

Run:

```sh
make run
```

### Release DMG

GitHub Actions automatically builds a release DMG on every push to `main`. The generated `NotSleep.dmg` can be downloaded from the workflow run artifacts.

The release DMG is signed with Developer ID and notarized by Apple so Gatekeeper does not block it. Before running the workflow, add these values to the GitHub repository secrets.

```text
DEVELOPER_ID_CERTIFICATE_BASE64
DEVELOPER_ID_CERTIFICATE_PASSWORD
DEVELOPER_ID_APPLICATION
KEYCHAIN_PASSWORD
APPLE_ID
APPLE_TEAM_ID
APPLE_APP_SPECIFIC_PASSWORD
```

`DEVELOPER_ID_APPLICATION` is the certificate name shown in Keychain Access, in the form `Developer ID Application: ... (TEAMID)`.

When pushing a `v*` tag such as `v1.0.0`, the workflow also creates a GitHub Release and attaches the DMG.

```sh
git tag v1.0.0
git push origin v1.0.0
```

### Notes

On first launch, NotSleep installs a small helper so it can run `pmset disablesleep` without asking for authentication every time. Administrator authentication is required only for this initial setup.

Installed files:

```text
/Library/PrivilegedHelperTools/local.notsleep.pmset-helper
/etc/sudoers.d/local-notsleep
```

To restore sleep manually, turn sleep back on in the app or run:

```sh
sudo pmset -a disablesleep 0
```

### Use of AI

AI assistance was used for the design, implementation, and README drafting of this app. The final content and behavior were reviewed by the developer.

### License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.
