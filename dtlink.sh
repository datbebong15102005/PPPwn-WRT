#!/bin/sh

source "$(cd "$(dirname "$0")" && pwd)/settings.cfg"

if [ "$dtl" != "true" ]; then
    exit 0
fi

INTERFACE="$dtlan"

# Hàm check trạng thái mạng
check_link_status() {
    ifconfig "$INTERFACE" | grep -q "RUNNING"
}

# Hàm lấy tốc độ
get_link_speed() {
    cat /sys/class/net/"$INTERFACE"/speed 2>/dev/null || echo 0
}

# Tắt service cũ để tránh xung đột
/etc/init.d/pppwn stop

# Bật đèn báo hiệu
if [ "$led" != "none" ] && [ "$led" != "" ]; then
    echo "default-on" > /sys/class/leds/${led}/trigger
fi

echo "Watchdog started on $INTERFACE"
echo "Initializing... (Waiting 5s for interface to settle)"
sleep 5

# Check trạng thái ban đầu
# Nếu vừa bật script mà thấy có mạng 1Gbps thì không kích hack
if check_link_status; then
    INIT_SPEED=$(get_link_speed)
    if [ "$INIT_SPEED" -ge 1000 ]; then
        echo ">> System active (1000Mbps). Skipping initial hack. Monitoring..."
    else
        echo ">> System detected at ${INIT_SPEED}Mbps. Monitoring..."
    fi
else
    echo ">> Link is DOWN at startup. Ready to catch boot event."
fi

# Vòng lặp chính
while true; do
    if check_link_status; then
        # Mạng vẫn ổn, ngủ tiếp
        sleep 5
    else
        # Sự kiện mất kết nối (Rút dây / Tắt máy / Rest Mode)
        echo "Link DOWN detected! Waiting for reconnection..."
        
        # Chờ mạng có lại
        while true; do
            if check_link_status; then
                echo "Link UP detected! Negotiating speed..."
                sleep 5 # Chờ đàm phán tốc độ
                
                CURRENT_SPEED=$(get_link_speed)
                echo "Negotiated Speed: ${CURRENT_SPEED}Mbps"
                
                if [ "$CURRENT_SPEED" -ge 1000 ]; then
                    echo ">> Speed is 1Gbps. PS4 REBOOT DETECTED."
                    # Chỉ thoát vòng lặp chờ để xuống dưới kích hack
                    # khi tốc độ là 1Gbps
                    break 2
                else
                    echo ">> Speed is ${CURRENT_SPEED}Mbps. PS4 is in REST MODE."
                    echo ">> Ignoring... Returning to monitor mode."
                    # Quay lại vòng lặp chính, tiếp tục canh gác
                    break 1 
                fi
            fi
            sleep 2
        done
    fi
done

# Kích hoạt hack (Chỉ chạy xuống đây khi Break 2)
echo "Target confirmed. Starting PPPwn..."

if [ "$led" != "none" ] && [ "$led" != "" ]; then
    echo "none" > /sys/class/leds/${led}/trigger
fi

/etc/init.d/pppwn start
