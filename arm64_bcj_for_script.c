#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include "../ROFS_XMAN/0.src/xz/src/common/tuklib_integer.h"

// 检查系统的字节序，判断是小端还是大端
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#define IS_LITTLE_ENDIAN 1
#else
#define IS_LITTLE_ENDIAN 0
#endif

// 如果是大端系统，定义字节交换宏
#ifndef bswap32
#define bswap32(n) (uint32_t)( \
      (((n) & UINT32_C(0x000000FF)) << 24) | \
      (((n) & UINT32_C(0x0000FF00)) << 8)  | \
      (((n) & UINT32_C(0x00FF0000)) >> 8)  | \
      (((n) & UINT32_C(0xFF000000)) >> 24) \
    )
#endif

// 读取32位小端整数
static inline uint32_t read32le(const uint8_t *buf) {
    uint32_t num;
    memcpy(&num, buf, sizeof(num));
    
    // 如果系统是大端序，则进行字节交换
    if (!IS_LITTLE_ENDIAN) {
        num = bswap32(num);
    }
    
    return num;
}

// 写入32位小端整数
static inline void write32le(uint8_t *buf, uint32_t num) {
    if (!IS_LITTLE_ENDIAN) {
        num = bswap32(num);
    }
    
    memcpy(buf, &num, sizeof(num));
}


static size_t arm64_code(uint32_t now_pos, bool is_encoder,
		uint8_t *buffer, size_t size)
{
	size_t i;

	// Clang 14.0.6 on x86-64 makes this four times bigger and 40 % slower
	// with auto-vectorization that is enabled by default with -O2.
	// Such vectorization bloat happens with -O2 when targeting ARM64 too
	// but performance hasn't been tested.
#ifdef __clang__
#	pragma clang loop vectorize(disable)
#endif
	for (i = 0; i + 4 <= size; i += 4) {
		uint32_t pc = (uint32_t)(now_pos + i);
		uint32_t instr = read32le(buffer + i);

		if ((instr >> 26) == 0x25) {
			// BL instruction:
			// The full 26-bit immediate is converted.
			// The range is +/-128 MiB.
			//
			// Using the full range is helps quite a lot with
			// big executables. Smaller range would reduce false
			// positives in non-code sections of the input though
			// so this is a compromise that slightly favors big
			// files. With the full range only six bits of the 32
			// need to match to trigger a conversion.
			const uint32_t src = instr;
			instr = 0x94000000;

			pc >>= 2;
			if (!is_encoder)
				pc = 0U - pc;

			instr |= (src + pc) & 0x03FFFFFF;
			write32le(buffer + i, instr);

		} else if ((instr & 0x9F000000) == 0x90000000) {
			// ADRP instruction:
			// Only values in the range +/-512 MiB are converted.
			//
			// Using less than the full +/-4 GiB range reduces
			// false positives on non-code sections of the input
			// while being excellent for executables up to 512 MiB.
			// The positive effect of ADRP conversion is smaller
			// than that of BL but it also doesn't hurt so much in
			// non-code sections of input because, with +/-512 MiB
			// range, nine bits of 32 need to match to trigger a
			// conversion (two 10-bit match choices = 9 bits).
			const uint32_t src = ((instr >> 29) & 3)
					| ((instr >> 3) & 0x001FFFFC);

			// With the addition only one branch is needed to
			// check the +/- range. This is usually false when
			// processing ARM64 code so branch prediction will
			// handle it well in terms of performance.
			//
			//if ((src & 0x001E0000) != 0
			// && (src & 0x001E0000) != 0x001E0000)
			if ((src + 0x00020000) & 0x001C0000)
				continue;

			instr &= 0x9000001F;

			pc >>= 12;
			if (!is_encoder)
				pc = 0U - pc;

			const uint32_t dest = src + pc;
			instr |= (dest & 3) << 29;
			instr |= (dest & 0x0003FFFC) << 3;
			instr |= (0U - (dest & 0x00020000)) & 0x00E00000;
			write32le(buffer + i, instr);
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

    size_t processed_size = arm64_code(now_pos, is_encoder, buffer, file_size);
    fwrite(buffer, 1, (size_t)file_size, output);

    fclose(input);
    fclose(output);

    return 0;
}