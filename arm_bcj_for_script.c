#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

static size_t arm_code(uint32_t now_pos, bool is_encoder,
		uint8_t *buffer, size_t size)
{
	size_t i;
	for (i = 0; i + 4 <= size; i += 4) {
		if (buffer[i + 3] == 0xEB) {
			uint32_t src = ((uint32_t)(buffer[i + 2]) << 16)
					| ((uint32_t)(buffer[i + 1]) << 8)
					| (uint32_t)(buffer[i + 0]);
			src <<= 2;

			uint32_t dest;
			if (is_encoder)
				dest = now_pos + (uint32_t)(i) + 8 + src;
			else
				dest = src - (now_pos + (uint32_t)(i) + 8);

			dest >>= 2;
			buffer[i + 2] = (dest >> 16);
			buffer[i + 1] = (dest >> 8);
			buffer[i + 0] = dest;
		}
	}

	return i;
}

int main(int argc, char *argv[])
{

    const char *input_file = argv[1];
    const char *output_file = argv[2];
    bool is_encoder = (atoi(argv[3]) != 0);

    FILE *input = fopen(input_file, "rb");
    if (input == NULL) {
        perror("Failed to open input file");
        return 1;
    }

    FILE *output = fopen(output_file, "wb");
    if (output == NULL) {
        perror("Failed to open output file");
        fclose(input);
        return 1;
    }

    fseek(input, 0, SEEK_END); // 定位到文件末尾
    long file_size = ftell(input); // 获取文件指针当前位置，即文件大小
    fseek(input, 0, SEEK_SET); // 将文件指针重新定位到文件开头

    // Buffer for file content
    // uint8_t buffer[BUFFER_SIZE];
    uint8_t *buffer = (uint8_t *)malloc(file_size + 1); // 加1是为了存放字符串结束符 '\0'
    size_t read_size;

    uint32_t now_pos = 0;

    size_t result = fread(buffer, 1, file_size, input);

    if (result != file_size) {
        fprintf(stderr, "读取文件失败\n");
        exit(1);
    }

    size_t processed_size = arm_code(now_pos, is_encoder, buffer, file_size);
    fwrite(buffer, 1, (size_t)file_size, output);

    fclose(input);
    fclose(output);

    return 0;
}
