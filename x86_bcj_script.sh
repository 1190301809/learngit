#!/bin/bash

# 设置目录
input_dir="x86_binary_files"
output_dir_bcj="x86_binary_files_bcj"
output_dir_compressed="x86_binary_files_compressed"
output_file="file_sizes.txt"

# 确保输出文件是空的
> "$output_file"

# 创建输出目录
mkdir -p "$output_dir_bcj"
mkdir -p "$output_dir_compressed"

# 处理并编码文件
for input_file in "$input_dir"/*; do
    if [ -f "$input_file" ]; then
        filename=$(basename "$input_file")
        output_file_bcj="$output_dir_bcj/${filename%.*}_bcj.${filename##*.}"
        ./x86_bcj_for_script.exe "$input_file" "$output_file_bcj" 1
    fi
done

# 压缩原始文件和bcj编码后的文件
for dir in "$input_dir" "$output_dir_bcj"; do
    for file in "$dir"/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            original_file_size=$(stat -c%s "$file")
            output_file_compressed="$output_dir_compressed/$filename.xz"
            xz -c "$file" > "$output_file_compressed"
            compressed_file_size=$(stat -c%s "$output_file_compressed")

            # 计算压缩率（使用纯 Bash）
            if [ $original_file_size -ne 0 ]; then
                compression_ratio=$(awk "BEGIN {printf \"%.2f\", ($compressed_file_size / $original_file_size) * 100}")
            else
                compression_ratio=0
            fi
            
            # 将文件名、压缩后文件大小和压缩率写入输出文件
            echo "$filename: Compressed Size = $compressed_file_size bytes, Compression Ratio = $compression_ratio%" >> "$output_file"
        fi
    done
done

# # 遍历输入目录中的所有文件并获取它们的大小
# for file in "$output_dir_compressed"/*; do
#   if [ -f "$file" ]; then
#     # 获取文件大小和文件名
#     file_size=$(stat -c%s "$file")
#     file_name=$(basename "$file")
    
#     # 将文件名和文件大小写入输出文件
#     echo "$file_name: $file_size bytes" >> "$output_file"
#   fi
# done

echo "处理完成，所有文件已放入 $output_dir_bcj 和 $output_dir_compressed 目录中。"