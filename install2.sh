#!/bin/bash

# 1. 检查并尝试安装基础网络工具
if [ -f /etc/debian_version ]; then
    sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y curl iputils-ping > /dev/null 2>&1
elif [ -f /etc/redhat-release ]; then
    sudo yum install -y curl iputils > /dev/null 2>&1
fi

# 2. 定义待测试的服务列表
TARGETS=(
    "X|x.com"
    "Apple|apple.com"
    "Disney|disneyplus.com"
    "Instagram|instagram.com"
    "ChatGPT|openai.com"
    "Google|google.com"
    "Claude|claude.ai"
    "Facebook|facebook.com"
    "AWS|aws.amazon.com"
    "YouTube|youtube.com"
    "OneDrive|onedrive.live.com"
    "Twitch|twitch.tv"
    "Microsoft|m365.cloud.microsoft"
    "Pornhub|pornhub.com"
    "TikTok|tiktok.com"
    "Steam|steampowered.com"
    "Netflix|fast.com"
    "GitHub|github.com"
    "NodeSeek|nodeseek.com"
    "Telegram.dc1|149.154.175.53"
    "Telegram.dc5|91.108.56.168"
    "Akile.hkb|141.11.149.247"
    "Akile.tw|82.152.91.201"
    "Bytevirt.sg|82.152.91.201"
    "Softbank.jp|188.253.125.104"
    "Bitsflow.us|216.183.230.60"
    
)

TMP_FILE="/tmp/ping_results.txt"
> "$TMP_FILE"

echo "=== 1. 正在测试网络延迟 (后台并发中...) ==="

# 3. 并发执行 Ping 测试
for item in "${TARGETS[@]}"; do
    name=$(echo "$item" | cut -d'|' -f1)
    host=$(echo "$item" | cut -d'|' -f2)
    
    (
        # 发送4个包，限时4秒
        ping_out=$(ping -c 4 -w 4 "$host" 2>&1)
        if [ $? -eq 0 ]; then
            # 提取丢包率
            loss=$(echo "$ping_out" | grep -oP '\d+(?=% packet loss)' || echo "$ping_out" | grep -oP '\d+(?=% loss)' || echo "0")
            # 提取平均延迟
            avg=$(echo "$ping_out" | grep -oP 'rtt min/avg/max/mdev = [0-9\.]+/支配?\K[0-9\.]+' || echo "$ping_out" | tail -n 1 | awk -F '/' '{print $5}')
            
            # 如果没有提取到，尝试兜底方案
            if [ -z "$avg" ]; then
                avg=$(echo "$ping_out" | grep 'rtt' | cut -d'=' -f2 | cut -d'/' -f2 | tr -d ' ')
            fi
        else
            loss="100"
            avg="9999"
        fi
        
        # 判定状态
        if [ "$loss" -eq 100 ] || [ -z "$avg" ]; then
            status="❌ 失败"
            display_time="Timeout"
            sort_key="9999"
        else
            sort_key=$(printf "%08.2f" "$avg")
            display_time="${avg}ms"
            # 依据延迟给状态
            if (( $(echo "$avg < 30" | bc -l 2>/dev/null || [ "${avg%.*}" -lt 30 ] && echo 1 || echo 0) )); then
                status="✓ 优秀"
            elif (( $(echo "$avg < 100" | bc -l 2>/dev/null || [ "${avg%.*}" -lt 100 ] && echo 1 || echo 0) )); then
                status="◆ 良好"
            else
                status="▲ 较差"
            fi
        fi
        
        # 将结果写入临时文件，用于后续排序
        echo "${sort_key}|${name}|${host}|${display_time}|${loss}%|${status}" >> "$TMP_FILE"
    ) &
done

# 等待所有后台任务完成
wait

# 4. 格式化输出对齐的表格
echo -e "\n测试完成！延迟测试结果表格："
echo "================================================================================="
printf "%-6s %-15s %-25s %-12s %-10s %-10s\n" "排名" "服务" "域名/IP" "延迟" "丢包率" "状态"
echo "================================================================================="

rank=1
sort -n "$TMP_FILE" | while IFS='|' read -r sort_key name host display_time loss status; do
    printf "%-6s %-15s %-25s %-12s %-10s %-10s\n" "$rank" "$name" "$host" "$display_time" "$loss" "$status"
    ((rank++))
done

echo "================================================================================="

# 清理临时文件
rm -f "$TMP_FILE"
