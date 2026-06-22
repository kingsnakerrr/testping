#!/bin/bash

# 1. 准备工作：创建临时目录，自动适配系统并下载/安装最小化依赖
TMP_DIR="/tmp/vps_ping_test"
PY_FILE="${TMP_DIR}/ping_test.py"

echo "=== 1. 正在检查并准备 VPS 环境 ==="
if [ -f /etc/debian_version ]; then
    sudo apt-get update -y && sudo apt-get install -y python3 curl iputils-ping > /dev/null 2>&1
elif [ -f /etc/redhat-release ]; then
    sudo yum install -y python3 curl iputils > /dev/null 2>&1
fi

mkdir -p "$TMP_DIR"

# 2. 将核心的 Python 并发网络测试代码写入临时文件
cat << 'EOF' > "$PY_FILE"
import os
import re
import sys
import subprocess
from concurrent.futures import ThreadPoolExecutor

TARGETS = [
    ("X", "x.com"), ("Apple", "apple.com"), ("Disney", "disneyplus.com"),
    ("Instagram", "instagram.com"), ("ChatGPT", "openai.com"), ("Google", "google.com"),
    ("Claude", "claude.ai"), ("Facebook", "facebook.com"), ("AWS", "aws.amazon.com"),
    ("YouTube", "youtube.com"), ("OneDrive", "onedrive.live.com"), ("Twitch", "twitch.tv"),
    ("Microsoft", "m365.cloud.microsoft"), ("Pornhub", "pornhub.com"), ("TikTok", "tiktok.com"),
    ("Steam", "steampowered.com"), ("Netflix", "fast.com"), ("GitHub", "github.com"),
    ("NodeSeek", "nodeseek.com"), ("Telegram", "91.108.56.168")
]

def ping_target(name, host):
    command = ['ping', '-c', '4', '-w', '4', host]
    try:
        output = subprocess.check_output(command, stderr=subprocess.STDOUT, universal_newlines=True, timeout=5)
        loss_match = re.search(r'(\d+)%\s*packet loss', output)
        packet_loss = int(loss_match.group(1)) if loss_match else 100
        
        avg_time = float('inf')
        if packet_loss < 100:
            avg_match = re.search(r'rtt\s+min/avg/max/mdev\s*=\s*[\d\.]+/([\d\.]+)', output)
            if avg_match:
                avg_time = float(avg_match.group(1))
            else:
                lines = output.splitlines()
                for line in lines:
                    if 'min/avg/max' in line or 'rtt' in line:
                        avg_time = float(line.split('=')[1].split('/')[1].strip())
    except Exception:
        packet_loss = 100
        avg_time = float('inf')

    if packet_loss == 100: status = "❌ 失败"
    elif avg_time <= 30: status = "✓ 优秀"
    elif avg_time <= 100: status = "◆ 良好"
    else: status = "▲ 较差"

    display_time = f"{avg_time:.1f}ms" if avg_time != float('inf') else "Timeout"
    return {"name": name, "host": host, "latency": avg_time, "display_time": display_time, "loss": f"{packet_loss}%", "status": status}

def main():
    print("⏳ 测试开始，正在并发测试网络延迟...")
    results = []
    with ThreadPoolExecutor(max_workers=15) as executor:
        futures = [executor.submit(ping_target, name, host) for name, host in TARGETS]
        for future in futures: results.append(future.result())
            
    results.sort(key=lambda x: x['latency'])
    
    print("\n测试完成！延迟测试结果表格：")
    print("=" * 85)
    print(f"{'排名':<6}{'服务':<15}{'域名/IP':<25}{'延迟':<12}{'丢包率':<10}{'状态':<10}")
    print("=" * 85)
    for idx, r in enumerate(results, 1):
        print(f"{idx:<6}{r['name']:<15}{r['host']:<25}{r['display_time']:<12}{r['loss']:<10}{r['status']:<10}")
    print("=" * 85)

if __name__ == '__main__':
    main()
EOF

# 3. 运行测试并自动清理
echo -e "\n=== 2. 开始执行延迟测试 ==="
python3 "$PY_FILE"
rm -rf "$TMP_DIR"
