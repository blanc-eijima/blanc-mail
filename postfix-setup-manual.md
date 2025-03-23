# さくらVPSでのPostfixメール配信システム構築マニュアル

## 目次
1. [前提条件](#前提条件)
2. [Postfixのインストールと基本設定](#postfixのインストールと基本設定)
3. [SPF設定](#spf設定)
4. [DKIM設定](#dkim設定)
5. [DMARC設定](#dmarc設定)
6. [送信速度制限の設定](#送信速度制限の設定)
7. [動作確認](#動作確認)

## 前提条件

- さくらVPS（CentOS 7.x）
- root権限でのアクセス
- 以下のドメイン情報が必要：
  - メールサーバーのFQDN
  - 送信元ドメイン
  - DNSの管理権限

## Postfixのインストールと基本設定

### 1. パッケージのインストール

```bash
# システムの更新
yum update -y

# 必要なパッケージのインストール
yum install -y postfix mailx cyrus-sasl-plain

# Postfixの自動起動設定
systemctl enable postfix
systemctl start postfix
```

### 2. 基本設定

/etc/postfix/main.cf に以下の設定を追加：

```conf
# メールサーバーの基本設定
myhostname = mail.example.com
mydomain = example.com
myorigin = $mydomain
inet_interfaces = all
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain

# SMTP認証の設定
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = $myhostname
broken_sasl_auth_clients = yes

# TLS設定
smtpd_tls_cert_file = /etc/pki/tls/certs/mail.example.com.crt
smtpd_tls_key_file = /etc/pki/tls/private/mail.example.com.key
smtpd_tls_security_level = may
smtp_tls_security_level = may
smtp_tls_loglevel = 1
```

## SPF設定

### 1. DNSレコードの追加

ドメインのDNS設定に以下のTXTレコードを追加：

```
example.com.    IN    TXT    "v=spf1 ip4:XXX.XXX.XXX.XXX ~all"
```

※ XXX.XXX.XXX.XXXはさくらVPSのIPアドレスに置き換えてください。

## DKIM設定

### 1. OpenDKIMのインストール

```bash
# EPELリポジトリの追加
yum install -y epel-release

# OpenDKIMのインストール
yum install -y opendkim
```

### 2. OpenDKIMの設定

/etc/opendkim.conf の設定：

```conf
Domain                  example.com
KeyFile                 /etc/opendkim/keys/example.com/default.private
Selector                default
Socket                  inet:8891@localhost
```

### 3. 鍵の生成

```bash
mkdir -p /etc/opendkim/keys/example.com
cd /etc/opendkim/keys/example.com
opendkim-genkey -D /etc/opendkim/keys/example.com/ -d example.com -s default
```

### 4. DNSレコードの追加

生成された default.txt の内容をDNSに追加：

```
default._domainkey.example.com.    IN    TXT    "v=DKIM1; k=rsa; p=XXXXXXXX"
```

## DMARC設定

### 1. DNSレコードの追加

```
_dmarc.example.com.    IN    TXT    "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com; ruf=mailto:dmarc@example.com; pct=100"
```

## 送信速度制限の設定

### 1. Postfixの送信制限設定

/etc/postfix/main.cf に以下を追加：

```conf
# 送信速度制限
smtpd_client_connection_rate_limit = 10
smtpd_client_message_rate_limit = 30
initial_destination_concurrency = 2
default_destination_rate_delay = 1s
default_destination_concurrency_limit = 5

# メッセージサイズ制限
message_size_limit = 10240000
mailbox_size_limit = 51200000

# キュー設定
maximal_queue_lifetime = 1d
bounce_queue_lifetime = 1d
```

### 2. Postfixキューの監視設定

/etc/postfix/master.cf に以下を追加：

```conf
smtp      inet  n       -       n       -       -       smtpd
  -o smtpd_client_connection_count_limit=10
  -o smtpd_client_connection_rate_limit=30
  -o smtpd_client_message_rate_limit=30
  -o smtpd_error_sleep_time=1s
```

## 動作確認

### 1. 各サービスの起動確認

```bash
# サービスステータスの確認
systemctl status postfix
systemctl status opendkim

# ログの確認
tail -f /var/log/maillog
```

### 2. テストメールの送信

```bash
echo "Test mail" | mail -s "Test Subject" test@example.com
```

### 3. メール認証の確認

受信したメールのヘッダーで以下の項目を確認：
- SPF: pass
- DKIM: pass
- DMARC: pass

## トラブルシューティング

### 1. ログの確認

```bash
# メールログの確認
tail -f /var/log/maillog

# Postfixキューの確認
mailq

# キューの強制実行
postqueue -f
```

### 2. 一般的な問題と解決方法

1. SPFレコードが反映されない
   - DNSのTTLを確認
   - dig コマンドでDNSレコードを確認

2. DKIMが機能しない
   - OpenDKIMのログを確認
   - 鍵のパーミッションを確認

3. 送信制限による遅延
   - mailqコマンドでキューを確認
   - 設定値の調整を検討

## セキュリティ強化のための追加設定

### 1. Postfixのセキュリティ設定

/etc/postfix/main.cf に以下を追加：

```conf
# SMTP認証の強化
smtpd_recipient_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination,
    reject_invalid_hostname,
    reject_non_fqdn_hostname,
    reject_non_fqdn_sender,
    reject_non_fqdn_recipient,
    reject_unknown_sender_domain,
    reject_unknown_recipient_domain,
    reject_rbl_client zen.spamhaus.org

# TLSの強化
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3
smtpd_tls_mandatory_ciphers = high
smtpd_tls_exclude_ciphers = aNULL, eNULL, EXPORT, DES, RC4, MD5, PSK, aECDH, EDH-DSS-DES-CBC3-SHA, EDH-RSA-DES-CBC3-SHA, KRB5-DES, CBC3-SHA
```

### 2. システムセキュリティの強化

```bash
# ファイアウォ���ルの設定
firewall-cmd --permanent --add-service=smtp
firewall-cmd --permanent --add-service=smtps
firewall-cmd --permanent --add-service=submission
firewall-cmd --reload

# SELinuxの設定
setsebool -P httpd_can_sendmail 1
```