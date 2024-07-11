#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#define BUFFER_SIZE 4096

#define Test86MSByte(b) ((b) == 0 || (b) == 0xFF)


typedef struct {
	uint32_t prev_mask;
	uint32_t prev_pos;
} lzma_simple_x86;

static size_t
x86_code(void *simple_ptr, uint32_t now_pos, bool is_encoder,
		uint8_t *buffer, size_t size)
{
	static const bool MASK_TO_ALLOWED_STATUS[8]
		= { true, true, true, false, true, false, false, false };

	static const uint32_t MASK_TO_BIT_NUMBER[8]
			= { 0, 1, 2, 2, 3, 3, 3, 3 };

	lzma_simple_x86 *simple = simple_ptr;
	uint32_t prev_mask = simple->prev_mask;
	uint32_t prev_pos = simple->prev_pos;

	if (size < 5)
		return 0;

	if (now_pos - prev_pos > 5)
		prev_pos = now_pos - 5;

	const size_t limit = size - 5;
	size_t buffer_pos = 0;

	while (buffer_pos <= limit) {
		uint8_t b = buffer[buffer_pos];
		if (b != 0xE8 && b != 0xE9) {
			++buffer_pos;
			continue;
		}

		const uint32_t offset = now_pos + (uint32_t)(buffer_pos)
				- prev_pos;
		prev_pos = now_pos + (uint32_t)(buffer_pos);

		if (offset > 5) {
			prev_mask = 0;
		} else {
			for (uint32_t i = 0; i < offset; ++i) {
				prev_mask &= 0x77;
				prev_mask <<= 1;
			}
		}

		b = buffer[buffer_pos + 4];

		if (Test86MSByte(b)
			&& MASK_TO_ALLOWED_STATUS[(prev_mask >> 1) & 0x7]
				&& (prev_mask >> 1) < 0x10) {

			uint32_t src = ((uint32_t)(b) << 24)
				| ((uint32_t)(buffer[buffer_pos + 3]) << 16)
				| ((uint32_t)(buffer[buffer_pos + 2]) << 8)
				| (buffer[buffer_pos + 1]);

			uint32_t dest;
			while (true) {
				if (is_encoder)
					dest = src + (now_pos + (uint32_t)(
							buffer_pos) + 5);
				else
					dest = src - (now_pos + (uint32_t)(
							buffer_pos) + 5);

				if (prev_mask == 0)
					break;

				const uint32_t i = MASK_TO_BIT_NUMBER[
						prev_mask >> 1];

				b = (uint8_t)(dest >> (24 - i * 8));

				if (!Test86MSByte(b))
					break;

				src = dest ^ ((1U << (32 - i * 8)) - 1);
			}

			buffer[buffer_pos + 4]
					= (uint8_t)(~(((dest >> 24) & 1) - 1));
			buffer[buffer_pos + 3] = (uint8_t)(dest >> 16);
			buffer[buffer_pos + 2] = (uint8_t)(dest >> 8);
			buffer[buffer_pos + 1] = (uint8_t)(dest);
			buffer_pos += 5;
			prev_mask = 0;

		} else {
			++buffer_pos;
			prev_mask |= 1;
			if (Test86MSByte(b))
				prev_mask |= 0x10;
		}
	}

	simple->prev_mask = prev_mask;
	simple->prev_pos = prev_pos;

	return buffer_pos;
}

// 打印二进制数据的十六进制表示
void print_binary_data(const uint8_t *data, size_t size) {
    for (size_t i = 0; i < size; ++i) {
        printf("%02X ", data[i]);
        if ((i + 1) % 16 == 0) {
            printf("\n");
        }
    }
    printf("\n");
}


void read_binary_data(const char *input_file, const char *output_txt_file) {
    // 打开输入文件
    FILE *input = fopen(input_file, "rb");
    if (input == NULL) {
        perror("Failed to open input file");
        return;
    }

    // 移动文件指针到文件末尾，获取文件大小
    fseek(input, 0, SEEK_END);
    size_t input_size = ftell(input);
    fseek(input, 0, SEEK_SET);

    // 分配内存读取文件内容
    uint8_t *buffer = (uint8_t *)malloc(input_size);
    if (buffer == NULL) {
        perror("Failed to allocate memory");
        fclose(input);
        return;
    }

    // 读取文件内容到缓冲区
    size_t read_size = fread(buffer, 1, input_size, input);
    if (read_size != input_size) {
        perror("Failed to read input file");
        free(buffer);
        fclose(input);
        return;
    }

    // 打开输出文本文件
    FILE *output_txt = fopen(output_txt_file, "wb");
    if (output_txt == NULL) {
        perror("Failed to open output text file");
        free(buffer);
        fclose(input);
        return;
    }

    // 将二进制数据写入文本文件
    for (size_t i = 0; i < input_size; ++i) {
        fprintf(output_txt, "%02X ", buffer[i]);
        if ((i + 1) % 16 == 0) {
            fprintf(output_txt, "\n");
        }
    }

    // 清理资源
    free(buffer);
    fclose(output_txt);
    fclose(input);
}

int main(int argc, char *argv[])
{
    const char *input_file = "testfile";
    const char *output_file = "testfile_processed";
    bool is_encoder = true; // Set to true if encoding, false if decoding

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

    // Buffer for file content
    uint8_t buffer[BUFFER_SIZE];
    size_t read_size;

    // Initialize the BCJ state
    lzma_simple_x86 simple;
    simple.prev_mask = 0;
    simple.prev_pos = (uint32_t)(-5);

    uint32_t now_pos = 0;

    // Read the input file, process it and write to the output file
    while ((read_size = fread(buffer, 1, sizeof(buffer), input)) > 0) {
        size_t processed_size = x86_code(&simple, now_pos, is_encoder, buffer, read_size);
        fwrite(buffer, 1, processed_size + (size_t)4, output);
        now_pos += processed_size;
    }

    fclose(input);
    fclose(output);

    read_binary_data("testfile","before_bcj.txt");
    read_binary_data("testfile_processed","after_bcj.txt");

    return 0;
}