#!/bin/bash

# 确保传入了目录作为参数
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

dir="$1"

# 临时文件夹
temp_dir=$(mktemp -d)

# 对整个目录创建一个SquashFS镜像
mksquashfs "$dir" "$temp_dir/dir.xz.squashfs" -comp xz -noappend >/dev/null 2>&1
dir_xz_size=$(stat -c%s "$temp_dir/dir.xz.squashfs")

# 创建xz -Xbcj x86压缩的SquashFS镜像
mksquashfs "$dir" "$temp_dir/dir.xz.bcj.squashfs" -comp xz -Xbcj x86 -noappend >/dev/null 2>&1
dir_bcj_size=$(stat -c%s "$temp_dir/dir.xz.bcj.squashfs")

# 计算整个目录的优化率
dir_optimization=$(echo "$dir_xz_size $dir_bcj_size" | awk '{print (1 - $2/$1)*100}' | xargs printf "%.2f%%")

# 输出整个目录的结果
printf "|%-50s|%-12s|%-12s|%-15s|\n" "Directory" "XZ_size" "BCJ_size" "Opt_rate (%)"
printf "|%-50s|%-12d|%-12d|%-15s|\n" "$dir" "$dir_xz_size" "$dir_bcj_size" "$dir_optimization"

# 遍历目标目录下的所有文件
for file in "$dir"/*; do
    if [ -f "$file" ]; then
        filename=$(basename -- "$file")

        # 创建xz压缩的SquashFS镜像
        mksquashfs "$file" "$temp_dir/$filename.xz.squashfs" -comp xz -noappend >/dev/null 2>&1
        xz_size=$(stat -c%s "$temp_dir/$filename.xz.squashfs")

        # 创建xz -Xbcj x86压缩的SquashFS镜像
        mksquashfs "$file" "$temp_dir/$filename.xz.bcj.squashfs" -comp xz -Xbcj x86 -noappend >/dev/null 2>&1
        bcj_size=$(stat -c%s "$temp_dir/$filename.xz.bcj.squashfs")

        # 计算优化率
        optimization=$(echo "$xz_size $bcj_size" | awk '{print (1 - $2/$1)*100}' | xargs printf "%.2f%%")

        # 输出结果，文件名前加上 => 标志
        printf "|=>%-48s|%-12d|%-12d|%-15s|\n" "$filename" "$xz_size" "$bcj_size" "$optimization"

        # 删除临时镜像文件
        rm -f "$temp_dir/$filename.xz.squashfs" "$temp_dir/$filename.xz.bcj.squashfs"
    fi
done

# 清理临时文件夹
rm -rf "$temp_dir"



