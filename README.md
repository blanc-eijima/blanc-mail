# メール配信システム

このリポジトリは、さくらVPS上でPostfixを使用したメール配信システムを構築するためのスクリプトとマニュアルを提供します。

## 機能

- Postfixによるメール配信システムの構築
- SPF、DKIM、DMARCによるメール認証の設定
- 送信速度制限の実装
- セキュリティ設定の強化

## 使用方法

1. リポジトリをクローン：
```bash
git clone https://github.com/blanc-eijima/blanc-mail.git
cd blanc-mail
```

2. インストールスクリプトを実行：
```bash
cd setup-scripts
chmod +x install.sh
./install.sh
```

3. DNSレコードの設定：
スクリプト実行後に表示されるDNSレコード情報を、ドメインのDNS設定に追加してください。

## ディレクトリ構造

```
.
├── setup-scripts/     # セットアップスクリプト
├── config-templates/  # 設定ファイルのテンプレート
└── docs/             # ドキュメント
```

## 詳細な設定方法

詳細な設定方法については、[postfix-setup-manual.md](postfix-setup-manual.md)を参照してください。

## ライセンス

MIT

## 作者

blanc-eijima