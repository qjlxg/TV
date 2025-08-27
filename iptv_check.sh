#!/bin/bash

# 设置最大并行任务数
max_parallel_jobs=10
test_count=0

# 清理旧的临时文件和结果文件
test -f tv_list.txt && rm tv_list.txt
test -f tv_list.txt.tmp && rm tv_list.txt.tmp

# 读取iptv_list.txt并逐行测试
while IFS=, read -r name url; do
    # 检查URL是否有效
    if [[ "$url" =~ ^http.* ]]; then
        echo "准备测试: $name"
        
        # 将测试任务推入后台并行执行
        (
            # 使用ffmpeg测试URL，限制测试时间为5秒
            # -nostdin 阻止 ffmpeg 进入交互模式
            # -v quiet 减少输出信息
            # -f null - 将输出重定向到空设备
            if ffmpeg -nostdin -i "$url" -t 5 -v quiet -f null - ; then
                echo "$name,$url" >> tv_list.txt.tmp
            fi
        ) &
        
        # 增加计数器
        ((test_count++))
        
        # 每达到最大并行数时，等待所有任务完成
        if ((test_count % max_parallel_jobs == 0)); then
            wait
        fi
    else
        # 复制非URL行，例如标题或注释
        echo "$name,$url" >> tv_list.txt.tmp
    fi
done < iptv_list.txt

# 等待所有剩余的后台任务完成
wait

# 将临时文件中的结果进行排序并去重，然后写入最终文件
echo "所有测试已完成，正在处理结果..."
sort -u -o tv_list.txt tv_list.txt.tmp

# 清理临时文件
rm tv_list.txt.tmp

echo "可用频道已保存到 tv_list.txt"
