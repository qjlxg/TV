#!/bin/bash

# 如果tv_list.txt存在，先删除它
test -f tv_list.txt && rm tv_list.txt

# 读取iptv_list.txt并逐行测试
while IFS=, read -r name url; do
    # 检查URL是否有效
    if [[ "$url" =~ ^http.* ]]; then
        echo "正在测试: $name"
        
        # 使用ffmpeg测试URL，限制测试时间为5秒
        # -v quiet 减少输出信息
        # -f null - 将输出重定向到空设备
        if ffmpeg -i "$url" -t 5 -v quiet -f null - ; then
            echo "测试成功，保存频道: $name"
            echo "$name,$url" >> tv_list.txt
        else
            echo "测试失败: $name"
        fi
    else
        # 复制非URL行，例如标题或注释
        echo "$name,$url" >> tv_list.txt
    fi
done < iptv_list.txt

echo "测试完成，可用频道已保存到 tv_list.txt"
