#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define NUM_TESTS 1000

uint32_t calculate_H(uint32_t a,
                     uint32_t b,
                     uint32_t c,
                     uint32_t d,
                     uint32_t e,
                     uint32_t f)
{
    uint32_t sum;
    uint32_t xor_result;
    uint32_t sub_result;
    uint32_t H;

    sum = a + b + c;

    xor_result = sum ^ d;

    sub_result = xor_result - e;

    H = sub_result | f;

    return H;
}


/*
 * rand() thường chỉ tạo được khoảng 15 hoặc 31 bit tùy hệ thống.
 * Hàm này ghép nhiều lần rand() để tạo giá trị uint32_t.
 */
uint32_t random_uint32(void)
{
    uint32_t value;

    value  = ((uint32_t)rand() & 0xFFFF);
    value |= ((uint32_t)rand() & 0xFFFF) << 16;

    return value;
}


int main(void)
{
    FILE *fp_input;
    FILE *fp_golden;

    uint32_t a;
    uint32_t b;
    uint32_t c;
    uint32_t d;
    uint32_t e;
    uint32_t f;

    uint32_t H;

    int i;

    /*
     * Dùng seed cố định.
     *
     * Mỗi lần chạy chương trình sẽ tạo đúng cùng
     * một bộ 1000 test vector.
     *
     * Điều này rất quan trọng để verification FPGA.
     */
    srand(12345);


    fp_input = fopen("input_data.txt", "w");

    if (fp_input == NULL)
    {
        printf("Cannot create input_data.txt\n");
        return 1;
    }


    fp_golden = fopen("golden_output.txt", "w");

    if (fp_golden == NULL)
    {
        printf("Cannot create golden_output.txt\n");

        fclose(fp_input);

        return 1;
    }


    for (i = 0; i < NUM_TESTS; i++)
    {
        /*
         * Generate random input
         */
        a = random_uint32();
        b = random_uint32();
        c = random_uint32();
        d = random_uint32();
        e = random_uint32();
        f = random_uint32();


        /*
         * Golden C model
         */
        H = calculate_H(a, b, c, d, e, f);


        /*
         * Ghi input dưới dạng HEX.
         *
         * Mỗi dòng:
         *
         * a b c d e f
         */
        fprintf(fp_input,
                "%08X %08X %08X %08X %08X %08X\n",
                a,
                b,
                c,
                d,
                e,
                f);


        /*
         * Golden output:
         *
         * mỗi dòng tương ứng với một test vector.
         */
        fprintf(fp_golden,
                "%08X\n",
                H);
    }


    fclose(fp_input);

    fclose(fp_golden);


    printf("Generated %d test vectors.\n", NUM_TESTS);

    printf("Input  : input_data.txt\n");
    printf("Golden : golden_output.txt\n");


    return 0;
}