#!/bin/bash

# 启用shell调试模式，打印每条执行的命令
set -x

# 设置最大并行任务数
max_parallel_jobs=10
test_count=0

# 清理旧的临时文件和结果文件
test -f tv_list.txt && rm tv_list.txt
test -f tv_list.txt.tmp && rm tv_list.txt.tmp

echo "开始频道测试，最大并行任务数：$max_parallel_jobs"

# 读取iptv_list.txt并逐行测试
while IFS=, read -r name url; do
    # 检查URL是否有效
    if [[ "$url" =~ ^http.* ]]; then
        echo "--> 准备测试: $name"
        
        # 将测试任务推入后台并行执行
        (
            echo "--- 正在测试: $name"
            if ffmpeg -nostdin -i "$url" -t 5 -v quiet -f null - ; then
                echo "$name,$url" >> tv_list.txt.tmp
                echo "--- 测试成功: $name"
            else
                echo "--- 测试失败: $name"
            fi
        ) &
        
        # 增加计数器
        ((test_count++))
        
        # 每达到最大并行数时，等待所有任务完成
        if ((test_count % max_parallel_jobs == 0)); then
            echo "当前已启动 $test_count 个任务，等待当前批次完成..."
            wait
            echo "当前批次已完成，继续下一批..."
        fi
    else
        # 复制非URL行，例如标题或注释
        echo "$name,$url" >> tv_list.txt.tmp
    fi
done < iptv_list.txt

# 等待所有剩余的后台任务完成
echo "所有任务已启动，等待剩余任务完成..."
wait

# 将临时文件中的结果进行排序并去重，然后写入最终文件
echo "所有测试已完成，正在处理结果..."
sort -u -o tv_list.txt tv_list.txt.tmp

# 清理临时文件
rm tv_list.txt.tmp

echo "可用频道已保存到 tv_list.txt"
