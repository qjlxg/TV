#!/bin/bash

# 启用shell调试模式，打印每条执行的命令
set -x

# 设置最大并行任务数
max_parallel_jobs=10
running_jobs=0

# 定义最低分辨率阈值（例如：720p）
min_width=1280
min_height=720

# 清理旧的临时文件和结果文件
test -f tv_list.txt && rm tv_list.txt
test -f tv_list.txt.tmp && rm tv_list.txt.tmp
test -f tv_list_test.txt.tmp && rm tv_list_test.txt.tmp

echo "开始处理 iptv_list.txt，并进行去重..."
# 对 iptv_list.txt 进行去重，然后写入临时文件
sort -u iptv_list.txt -o iptv_list.txt.unique
echo "去重完成，总频道数：$(wc -l < iptv_list.txt.unique)"

echo "开始频道测试，最大并行任务数：$max_parallel_jobs"

# 读取去重后的频道列表并逐行测试
while IFS=, read -r name url; do
    # 如果行不包含逗号，则将其视为标题或注释，直接复制
    if ! echo "$name,$url" | grep -q ','; then
        echo "$name,$url" >> tv_list.txt.tmp
        continue
    fi

    # 排除 https://mursor.ottiptv.cc/ 和 https://cdn5.163189.xyz/ 开头的节目源
    if [[ "$url" =~ ^https://mursor.ottiptv.cc/.* || "$url" =~ ^https://cdn5.163189.xyz/.* ]]; then
        echo "--> 跳过节目源: $name (URL: $url)"
        continue
    fi
    
    # 检查URL是否有效
    if [[ "$url" =~ ^http.* ]]; then
        echo "--> 准备测试: $name"
        
        # 将测试任务推入后台并行执行
        (
            echo "--- 正在测试: $name"
            # 使用 ffprobe 探测分辨率，并限制分析时间
            resolution=$(timeout 5s ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$url" 2>/dev/null)
            
            # 检查是否成功获取到分辨率
            if [[ -n "$resolution" ]]; then
                # 分割分辨率字符串
                IFS='x' read -r width height <<< "$resolution"
                
                # 检查分辨率是否达到或超过阈值
                if (( width >= min_width && height >= min_height )); then
                    echo "--- 测试成功: $name, 分辨率: $resolution"
                    echo "$name,$url,$resolution" >> tv_list_test.txt.tmp
                else
                    echo "--- 分辨率太低，跳过: $name, 分辨率: $resolution"
                fi
            else
                echo "--- 测试失败或无法获取分辨率: $name"
            fi
        ) &
        
        # 增加正在运行的任务计数
        ((running_jobs++))
        
        # 如果正在运行的任务数达到上限，则等待它们全部完成
        if ((running_jobs >= max_parallel_jobs)); then
            echo "当前正在运行 $running_jobs 个任务，等待当前批次完成..."
            wait
            echo "当前批次已完成，继续下一批..."
            running_jobs=0 # 重置计数器
        fi
    else
        # 复制非URL行，例如标题或注释
        echo "$name,$url" >> tv_list.txt.tmp
    fi
done < iptv_list.txt.unique

# 等待所有剩余的后台任务完成
echo "所有任务已启动，等待剩余任务完成..."
wait

# 将测试成功的频道信息追加到 tv_list.txt.tmp 中
cat tv_list_test.txt.tmp >> tv_list.txt.tmp

# 将临时文件中的结果进行排序并去重，然后写入最终文件
echo "所有测试已完成，正在处理结果..."
sort -u -o tv_list.txt tv_list.txt.tmp

# 清理临时文件
rm tv_list.txt.tmp
rm tv_list_test.txt.tmp
rm iptv_list.txt.unique

echo "可用频道已保存到 tv_list.txt"
