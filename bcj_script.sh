#!/bin/bash

# 设置目录
input_dir=${1:-x86_binary_files}
output_dir_bcj=${input_dir}_bcj
output_dir_compressed=${input_dir}_compressed
output_file="file_sizes.txt"

BCJ_EXE=${2:-./x86_bcj_for_script.exe}
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
	printf "%-45s%-25s%-25s%-25s%-25s\n" "Filename" "Size" "Bcj_Compressed_size" "Compressed_size" "Optimization rate"
	# printf "%-30s%    -15s%    -15s%    -15s\n" "文件名" "原始大小" "压缩大小" "bcj压缩大小"
	for f in `ls $input_dir/*`
	do
		filename=$(basename $f)
		# echo -n $filename
		printf "%-45s" $filename
		# 清空变量
    	size_xz=0
    	size_bcj_xz=0
		for x in `ls $output_dir_compressed/${filename}* | sort`
		do
			file_size=$(stat -c%s "$x")
			# echo -n " " $file_size
			printf "%-25s" $file_size
			if [[ "$x" == *.bcj.xz ]]; then
            	size_bcj_xz=$file_size
        	elif [[ "$x" == *.xz ]]; then
            	size_xz=$file_size
        	fi
		done
		# 计算优化率
    	if [[ $size_xz -gt 0 ]]; then
        	rate=$(awk "BEGIN { printf \"%.2f\", ($size_xz - $size_bcj_xz) / $size_xz * 100 }")
    	else
        	rate="N/A"
    	fi	
		printf "%-25s\n" "$rate%"	
		echo ""
	done
}
print_all_result
