#!/bin/bash

# メール配信システムセットアップスクリプト
# 注意: このスクリプトはroot権限で実行する必要があります

# エラーハンドリング
set -e
trap 'echo "エラーが発生しました。セットアップを中断します。"; exit 1' ERR

# 変数設定
DOMAIN="example.com"
HOSTNAME="mail.example.com"
IP_ADDRESS="xxx.xxx.xxx.xxx" # さくらVPSのIPアドレスに置き換えてください

# 関数定義
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "このスクリプトはroot権限で実行する必要があります"
        exit 1
    fi
}

install_packages() {
    echo "必要なパッケージをインストールしています..."
    yum update -y
    yum install -y epel-release
    yum install -y postfix mailx cyrus-sasl-plain opendkim
}

configure_postfix() {
    echo "Postfixを設定しています..."
    cp /etc/postfix/main.cf /etc/postfix/main.cf.backup
    cp /etc/postfix/master.cf /etc/postfix/master.cf.backup
    
    # main.cfの設定
    sed -i "s/^myhostname =.*/myhostname = $HOSTNAME/" /etc/postfix/main.cf
    sed -i "s/^mydomain =.*/mydomain = $DOMAIN/" /etc/postfix/main.cf
    
    # 設定ファイルのコピー
    cp ../config-templates/main.cf /etc/postfix/main.cf
    cp ../config-templates/master.cf /etc/postfix/master.cf
}

configure_opendkim() {
    echo "OpenDKIMを設定しています..."
    cp /etc/opendkim.conf /etc/opendkim.conf.backup
    
    # OpenDKIM設定ファイルのコピー
    cp ../config-templates/opendkim.conf /etc/opendkim.conf
    
    # 鍵の生成
    mkdir -p /etc/opendkim/keys/$DOMAIN
    cd /etc/opendkim/keys/$DOMAIN
    opendkim-genkey -D /etc/opendkim/keys/$DOMAIN/ -d $DOMAIN -s default
    
    # パーミッションの設定
    chown -R opendkim:opendkim /etc/opendkim/keys
    chmod 600 /etc/opendkim/keys/$DOMAIN/default.private
}

configure_firewall() {
    echo "ファイアウォールを設定しています..."
    firewall-cmd --permanent --add-service=smtp
    firewall-cmd --permanent --add-service=smtps
    firewall-cmd --permanent --add-service=submission
    firewall-cmd --reload
}

start_services() {
    echo "サービスを起動しています..."
    systemctl enable postfix
    systemctl enable opendkim
    systemctl start postfix
    systemctl start opendkim
}

print_dns_records() {
    echo "DNSレコードの設定情報:"
    echo "----------------------------------------"
    echo "SPFレコード:"
    echo "$DOMAIN.    IN    TXT    \"v=spf1 ip4:$IP_ADDRESS ~all\""
    echo ""
    echo "DKIMレコード:"
    cat /etc/opendkim/keys/$DOMAIN/default.txt
    echo ""
    echo "DMARCレコード:"
    echo "_dmarc.$DOMAIN.    IN    TXT    \"v=DMARC1; p=quarantine; rua=mailto:dmarc@$DOMAIN; ruf=mailto:dmarc@$DOMAIN; pct=100\""
    echo "----------------------------------------"
}

# メイン処理
main() {
    echo "メール配信システムのセットアップを開始します..."
    
    check_root
    install_packages
    configure_postfix
    configure_opendkim
    configure_firewall
    start_services
    print_dns_records
    
    echo "セットアップが完了しました"
    echo "DNSレコードを設定してください"
}

# スクリプトの実行
main