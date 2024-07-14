#!/bin/bash

# 设置目录
input_dir=${1:-x86_binary_files}
output_dir_bcj=${input_dir}_bcj
output_dir_compressed=${input_dir}_compressed
output_file="file_sizes.txt"

X86_BCJ_EXE=./x86_bcj_for_script.exe
XZ=/mnt/c/Users/mikuk/Desktop/share/ROFS_XMAN/1.bin/bin/xz


# 确保输出文件是空的
> "$output_file"

# 创建输出目录
mkdir -p "$output_dir_bcj"
mkdir -p "$output_dir_compressed"

# 处理并编码文件
for input_file in "$input_dir"/*; do
    if [ -f "$input_file" ]; then
        filename=$(basename "$input_file")
        output_file_bcj="$output_dir_bcj/${filename}.bcj"
        ${X86_BCJ_EXE} "$input_file" "$output_file_bcj" 1  &
    fi
done
wait

# 压缩原始文件和bcj编码后的文件
for dir in "$input_dir" "$output_dir_bcj"; do
    for file in "$dir"/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            original_file_size=$(stat -c%s "$file")
            output_file_compressed="$output_dir_compressed/$filename.xz"
            xz -c "$file" > "$output_file_compressed" &
        fi
    done
done
wait

rm -rf $output_dir_bcj

print_all_result()
{
	local filename
	local file_size
	local cur_name
	for f in $(ls $input_dir/*)
	do
		cp $f ${output_dir_compressed}
	done

	# echo "文件名 原始大小 压缩大小 bcj压缩大小"
	printf "%-30s%-20s%-20s%-20s\n" "Filename" "Size" "Bcj_Compressed_size" "Compressed_size"
	# printf "%-30s%    -15s%    -15s%    -15s\n" "文件名" "原始大小" "压缩大小" "bcj压缩大小"
	for f in `ls $input_dir/*`
	do
		filename=$(basename $f)
		# echo -n $filename
		printf "%-30s" $filename
		for x in `ls $output_dir_compressed/${filename}* | sort`
		do
			file_size=$(stat -c%s "$x")
			# echo -n " " $file_size
			printf "%-20s" $file_size
		done
		echo ""
	done
	#compressed_file_size=$(stat -c%s "$output_file_compressed")

        # 计算压缩率（使用纯 Bash）
	#if [ $original_file_size -ne 0 ]; then
	#	compression_ratio=$(awk "BEGIN {printf \"%.2f\", ($compressed_file_size / $original_file_size) * 100}")
	#else
	#	compression_ratio=0
	#fi
            
        # 将文件名、压缩后文件大小和压缩率写入输出文件
	#echo "$filename: Compressed Size = $compressed_file_size bytes, Compression Ratio = $compression_ratio%" >> "$output_file"

}
print_all_result
# # 遍历输入目录中的所有文件并获取它们的大小
# for file in "$output_dir_compressed"/*; do
#   if [ -f "$file" ]; then
#     # 获取文件大小和文件名
    
#     # 将文件名和文件大小写入输出文件
#     echo "$file_name: $file_size bytes" >> "$output_file"
#   fi
# done

#echo "处理完成，所有文件已放入 $output_dir_bcj 和 $output_dir_compressed 目录中。"
