#!/bin/bash

# 设置目录
input_dir=${1:-x86_binary_files}
output_dir_bcj=${input_dir}_bcj
output_dir_compressed=${input_dir}_compressed
output_dir_bcj_decompressed=${input_dir}_decompressed
output_file="file_sizes.txt"

BCJ_EXE=${2:-./x86_bcj_for_script.exe}
# xz=/mnt/c/Users/mikuk/Desktop/share/ROFS_XMAN/1.bin/bin/xz

# 确保输出文件是空的
> "$output_file"

# 创建输出目录
mkdir -p "$output_dir_bcj"
mkdir -p "$output_dir_compressed"
mkdir -p "$output_dir_bcj_decompressed"

# 处理并编码文件
for input_file in "$input_dir"/*; do
    if [ -f "$input_file" ]; then
        filename=$(basename "$input_file")
        output_file_bcj="$output_dir_bcj/${filename}.bcj"
        ${BCJ_EXE} "$input_file" "$output_file_bcj" 1  &
    fi
done
wait

# 压缩原始文件和bcj编码后的文件
for dir in "$input_dir" "$output_dir_bcj"; do
    for file in "$dir"/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            original_file_size=$(stat -c%s "$file")
            output_file_compressed="$output_dir_compressed/$filename.lz4"
            lz4 -c "$file" > "$output_file_compressed" &
        fi
    done
done
wait

# for file in "$output_dir_compressed"/*.bcj.lz4; do
#     if [ -f "$file" ]; then
#         filename=$(basename "$file" .lz4)  # 获取去掉 .lz4 后缀的文件名
#         decompressed_file="$output_dir_bcj_decompressed/$filename"

#         # 解压 .lz4 文件
#         lz4 -d -c "$file" > "$decompressed_file"

#         # 用 BCJ_EXE 进行解码
#         output_file_decoded="$output_dir_bcj_decompressed/${filename%.bcj}"
#         ${BCJ_EXE} "$decompressed_file" "$output_file_decoded" 0 &
#     fi
# done
# wait

rm -rf $output_dir_bcj

print_all_result()
{
    local filename
    local file_size
    local cur_name

    # echo "文件名 原始大小 压缩大小 bcj压缩大小"
    printf "|%-50s|%-12s|%-12s|%-12s|%-15s|\n" "Filename" "Size" "Compressed" "Bcj" "Opt_rate"
    
    for f in $(ls $input_dir/*); do
        filename=$(basename "$f")
        printf "|%-50s" "$filename"

        # 清空变量
        size_lz4=0
        size_bcj_lz4=0
        
        for x in $(ls $output_dir_compressed/${filename}* | sort); do
            file_size=$(stat -c%s "$x")
            if [[ "$x" == *.bcj.lz4 ]]; then
                size_bcj_lz4=$file_size
            elif [[ "$x" == *.lz4 ]]; then
                size_lz4=$file_size
            fi
        done

		printf "|%-12s" "$file_size"
        printf "|%-12s" "$size_lz4"
        printf "|%-12s" "$size_bcj_lz4"

        # 计算优化率
        if [[ $size_lz4 -gt 0 ]]; then
            rate=$(awk "BEGIN { printf \"%.2f\", ($size_lz4 - $size_bcj_lz4) / $size_lz4 * 100 }")
        else
            rate="N/A"
        fi
        printf "|%-15s|\n" "$rate%"
    done
}
print_all_result

