#!/bin/bash

# 设置最大并行任务数
max_parallel_jobs=10
running_jobs=0
total_channels=0

# 清理旧文件
test -f tv_list.txt && rm tv_list.txt
test -f tv_list.txt.tmp && rm tv_list.txt.tmp
test -f failed_channels.log && rm failed_channels.log
test -f errors.log && rm errors.log

echo "开始处理 iptv_list.txt，并进行去重..."
# 基于整行去重，保留频道名相同但 URL 不同的行
awk -F, '!seen[$0]++ {print}' iptv_list.txt | sort -u -o iptv_list.txt.unique
total_channels=$(wc -l < iptv_list.txt.unique)
echo "去重完成，总频道数：$total_channels"

echo "开始频道测试，最大并行任务数：$max_parallel_jobs"

# 读取去重后的频道列表
while IFS=, read -r name url; do
    if [[ "$url" =~ ^http.* ]]; then
        # 进度提示
        ((running_jobs++))
        echo "--> 准备测试: $name ($running_jobs/$total_channels)"

        # 检查是否已验证成功，跳过重复测试
        if grep -Fx "$name,$url" tv_list.txt 2>/dev/null; then
            echo "--- 跳过已验证成功的: $name"
            continue
        fi

        # 并行测试（无重试）
        (
            stdbuf -oL echo "--- 正在测试: $name ($url)"
            if timeout 5s ffmpeg -nostdin -user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
                -timeout 5000000 -i "$url" -t 5 -v quiet -f null - 2>> errors.log; then
                stdbuf -oL echo "--- 测试成功: $name"
                echo "$name,$url" >> tv_list.txt.tmp
            else
                stdbuf -oL echo "--- 测试失败: $name ($url)" | tee -a failed_channels.log
            fi
        ) &

        # 控制并行任务
        if (( running_jobs >= max_parallel_jobs )); then
            echo "当前正在运行 $running_jobs 个任务，等待当前批次完成..."
            wait
            echo "当前批次已完成，继续下一批..."
            running_jobs=0
        fi
    else
        # 复制非 URL 行（如 #genre# 或时间戳）
        echo "$name,$url" >> tv_list.txt.tmp
        stdbuf -oL echo "--- 保留非 URL 行: $name"
    fi
done < iptv_list.txt.unique

echo "所有任务已启动，等待剩余任务完成..."
wait

echo "所有测试已完成，正在处理结果..."
# 排序并去重输出
sort -u -o tv_list.txt tv_list.txt.tmp
echo "最终可用频道数：$(wc -l < tv_list.txt)"

# 清理临时文件
rm tv_list.txt.tmp
rm iptv_list.txt.unique

echo "可用频道已保存到 tv_list.txt"
echo "失败频道已记录到 failed_channels.log"
echo "错误详情已记录到 errors.log"

# 显示资源使用情况（用于调试）
echo "当前资源使用情况："
top -bn1 | head -n 5
