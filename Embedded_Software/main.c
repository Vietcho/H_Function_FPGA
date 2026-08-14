/*
 * h_accel_test.c
 *
 * Embedded Linux userspace test for H_Acceleration_IP using /dev/mem.
 *
 * H = (((A + B + C) ^ D) - E) | F
 *
 * IMPORTANT ADDRESSING RULE
 * -------------------------
 * The register addresses below are kept EXACTLY the same as the Arbiter:
 *
 *   0 -> A
 *   1 -> B
 *   2 -> C
 *   3 -> D
 *   4 -> E
 *   5 -> F
 *   6 -> LOAD
 *   7 -> START
 *   8 -> STOP
 *
 * Read:
 *   0 -> H
 *   1 -> READ_READY
 *
 * There is NO explicit "<< 2" operation anywhere in this program.
 *
 * Because the registers are 32-bit, the mapped IP base is accessed as a
 * volatile uint32_t pointer. Therefore:
 *
 *      ip_reg[0] -> register address 0
 *      ip_reg[1] -> register address 1
 *      ip_reg[2] -> register address 2
 *      ...
 *
 * This keeps the software register numbering identical to H_arbiter.v.
 *
 * Usage:
 *   sudo ./h_accel_test input_data.txt golden_output.txt
 */

#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

/* ================================================================
 * H_Acceleration_IP physical mapping
 * ================================================================ */

/*
 * User-provided physical base:
 *
 *     0xA000_0000
 *
 * Written in standard C hexadecimal syntax:
 */
#define H_ACCEL_BASE_PHYS 0xA0000000UL

/*
 * Register-space size requested by the user.
 *
 * If 0xFFFF means the highest valid offset, map 0x10000 bytes.
 */
#define H_ACCEL_REG_SIZE 0xFFFFUL
#define H_ACCEL_MAP_SIZE (H_ACCEL_REG_SIZE + 1UL)

/* ================================================================
 * Arbiter register addresses
 * ================================================================ */

/*
 * Keep these values identical to H_arbiter.v.
 *
 * DO NOT convert them to 0x00, 0x04, 0x08, ...
 */
#define A_BASE_ADDR 0U
#define B_BASE_ADDR 1U
#define C_BASE_ADDR 2U
#define D_BASE_ADDR 3U
#define E_BASE_ADDR 4U
#define F_BASE_ADDR 5U

#define LOAD_BASE_ADDR 6U
#define START_BASE_ADDR 7U
#define STOP_BASE_ADDR 8U

#define H_BASE_ADDR 0U
#define READ_READY_BASE_ADDR 1U

#define COMMAND_VALUE 1U

/*
 * Current RTL does not yet provide a persistent DONE flag.
 * Give the RTL enough time to complete READ -> COMPUTE -> WRITE.
 */
#define RESULT_WAIT_NS 1000L

/* ================================================================
 * MMIO context
 * ================================================================ */

struct mmio_context
{
    int fd;

    void *map_base;
    size_t map_length;

    /*
     * 32-bit register view of the IP.
     *
     * Software indexes this pointer using the SAME address number
     * defined in H_arbiter.v.
     */
    volatile uint32_t *ip_reg;
};

/* ================================================================
 * MMIO access functions
 * ================================================================ */

static inline void mmio_write32(volatile uint32_t *ip_reg,
                                uint32_t reg_addr,
                                uint32_t value)
{
    /*
     * No explicit <<2.
     *
     * Example:
     *     mmio_write32(ip_reg, A_BASE_ADDR, value);
     *
     * accesses:
     *     ip_reg[A_BASE_ADDR]
     */
    ip_reg[reg_addr] = value;

    __sync_synchronize();
}

static inline uint32_t mmio_read32(volatile uint32_t *ip_reg,
                                   uint32_t reg_addr)
{
    uint32_t value;

    __sync_synchronize();

    value = ip_reg[reg_addr];

    __sync_synchronize();

    return value;
}

/* ================================================================
 * /dev/mem open + mmap
 * ================================================================ */

static int mmio_open(struct mmio_context *ctx)
{
    long page_size;
    unsigned long page_mask;

    off_t page_base;
    off_t page_offset;

    size_t map_length;

    memset(ctx, 0, sizeof(*ctx));
    ctx->fd = -1;

    page_size = sysconf(_SC_PAGESIZE);

    if (page_size <= 0)
    {
        fprintf(stderr,
                "ERROR: Cannot determine system page size\n");

        return -1;
    }

    page_mask = (unsigned long)page_size - 1UL;

    /*
     * mmap() physical address must be page aligned.
     */
    page_base =
        (off_t)(H_ACCEL_BASE_PHYS & ~page_mask);

    page_offset =
        (off_t)(H_ACCEL_BASE_PHYS - (unsigned long)page_base);

    map_length =
        (size_t)page_offset +
        (size_t)H_ACCEL_MAP_SIZE;

    ctx->fd =
        open("/dev/mem",
             O_RDWR | O_SYNC);

    if (ctx->fd < 0)
    {
        fprintf(stderr,
                "ERROR: Cannot open /dev/mem: %s\n",
                strerror(errno));

        fprintf(stderr,
                "Run this application with root privilege.\n");

        return -1;
    }

    ctx->map_base =
        mmap(NULL,
             map_length,
             PROT_READ | PROT_WRITE,
             MAP_SHARED,
             ctx->fd,
             page_base);

    if (ctx->map_base == MAP_FAILED)
    {
        fprintf(stderr,
                "ERROR: mmap() failed: %s\n",
                strerror(errno));

        close(ctx->fd);

        ctx->fd = -1;
        ctx->map_base = NULL;

        return -1;
    }

    ctx->map_length = map_length;

    /*
     * Convert mapped virtual address to a 32-bit register pointer.
     */
    ctx->ip_reg =
        (volatile uint32_t *)((volatile uint8_t *)ctx->map_base + page_offset);

    return 0;
}

static void mmio_close(struct mmio_context *ctx)
{
    if ((ctx->map_base != NULL) &&
        (ctx->map_base != MAP_FAILED))
    {

        munmap(ctx->map_base,
               ctx->map_length);
    }

    if (ctx->fd >= 0)
    {
        close(ctx->fd);
    }

    ctx->fd = -1;
    ctx->map_base = NULL;
    ctx->map_length = 0;
    ctx->ip_reg = NULL;
}

/* ================================================================
 * H_Acceleration_IP operations
 * ================================================================ */

static void h_accel_load(volatile uint32_t *ip_reg,
                         uint32_t a,
                         uint32_t b,
                         uint32_t c,
                         uint32_t d,
                         uint32_t e,
                         uint32_t f)
{
    /*
     * Same sequence as H_function_core_tb.v:
     *
     *     LOAD
     *     A
     *     B
     *     C
     *     D
     *     E
     *     F
     */

    mmio_write32(ip_reg,
                 LOAD_BASE_ADDR,
                 COMMAND_VALUE);

    mmio_write32(ip_reg,
                 A_BASE_ADDR,
                 a);

    mmio_write32(ip_reg,
                 B_BASE_ADDR,
                 b);

    mmio_write32(ip_reg,
                 C_BASE_ADDR,
                 c);

    mmio_write32(ip_reg,
                 D_BASE_ADDR,
                 d);

    mmio_write32(ip_reg,
                 E_BASE_ADDR,
                 e);

    mmio_write32(ip_reg,
                 F_BASE_ADDR,
                 f);
}

static void h_accel_start(volatile uint32_t *ip_reg)
{
    mmio_write32(ip_reg,
                 START_BASE_ADDR,
                 COMMAND_VALUE);
}

static void h_accel_stop(volatile uint32_t *ip_reg)
{
    mmio_write32(ip_reg,
                 STOP_BASE_ADDR,
                 COMMAND_VALUE);
}

static uint32_t h_accel_read_h(volatile uint32_t *ip_reg)
{
    return mmio_read32(ip_reg,
                       H_BASE_ADDR);
}

static uint32_t h_accel_read_ready(volatile uint32_t *ip_reg)
{
    return mmio_read32(ip_reg,
                       READ_READY_BASE_ADDR) &
           0x1U;
}

static void h_accel_wait_result(void)
{
    struct timespec delay_time;

    delay_time.tv_sec = 0;
    delay_time.tv_nsec = RESULT_WAIT_NS;

    while (nanosleep(&delay_time,
                     &delay_time) != 0)
    {

        if (errno != EINTR)
        {
            break;
        }
    }
}

/* ================================================================
 * Main
 * ================================================================ */

int main(int argc,
         char *argv[])
{
    const char *input_file_path;
    const char *golden_file_path;

    FILE *input_file;
    FILE *golden_file;

    struct mmio_context mmio;

    uint32_t a;
    uint32_t b;
    uint32_t c;
    uint32_t d;
    uint32_t e;
    uint32_t f;

    uint32_t golden_h;
    uint32_t dut_h;

    unsigned long total_test_count;
    unsigned long pass_count;
    unsigned long fail_count;

    int input_scan_count;
    int golden_scan_count;

    /*
     * Default C-model files on the Linux server.
     * Command-line arguments, when provided, override these paths.
     */
    input_file_path =
        (argc >= 2) ?
        argv[1] :
        "/home/ubuntu/Hoangviet/FPGA/H_Function/H_Function_FPGA/"
        "C_Modeling/input_data.txt";

    golden_file_path =
        (argc >= 3) ?
        argv[2] :
        "/home/ubuntu/Hoangviet/FPGA/H_Function/H_Function_FPGA/"
        "C_Modeling/golden_output.txt";

    /* ============================================================
     * Open test files
     * ============================================================ */

    input_file =
        fopen(input_file_path,
              "r");

    if (input_file == NULL)
    {
        fprintf(stderr,
                "ERROR: Cannot open %s: %s\n",
                input_file_path,
                strerror(errno));

        return EXIT_FAILURE;
    }

    golden_file =
        fopen(golden_file_path,
              "r");

    if (golden_file == NULL)
    {
        fprintf(stderr,
                "ERROR: Cannot open %s: %s\n",
                golden_file_path,
                strerror(errno));

        fclose(input_file);

        return EXIT_FAILURE;
    }

    /* ============================================================
     * Map H_Acceleration_IP
     * ============================================================ */

    if (mmio_open(&mmio) != 0)
    {

        fclose(input_file);
        fclose(golden_file);

        return EXIT_FAILURE;
    }

    total_test_count = 0;
    pass_count = 0;
    fail_count = 0;

    printf("\n");
    printf("============================================================\n");
    printf("        H_ACCELERATION_IP EMBEDDED C TEST\n");
    printf("============================================================\n");

    printf("Physical base : 0x%08lX\n",
           H_ACCEL_BASE_PHYS);

    printf("Map size      : 0x%lX bytes\n",
           (unsigned long)H_ACCEL_MAP_SIZE);

    printf("Input file    : %s\n",
           input_file_path);

    printf("Golden file   : %s\n",
           golden_file_path);

    printf("------------------------------------------------------------\n");

    /* ============================================================
     * Run all test vectors
     * ============================================================ */

    while (1)
    {

        /*
         * input_data.txt format:
         *
         *     A B C D E F
         *
         * hexadecimal values.
         */
        input_scan_count =
            fscanf(input_file,
                   "%" SCNx32 " "
                   "%" SCNx32 " "
                   "%" SCNx32 " "
                   "%" SCNx32 " "
                   "%" SCNx32 " "
                   "%" SCNx32,
                   &a,
                   &b,
                   &c,
                   &d,
                   &e,
                   &f);

        /*
         * golden_output.txt format:
         *
         *     H
         */
        golden_scan_count =
            fscanf(golden_file,
                   "%" SCNx32,
                   &golden_h);

        /*
         * Normal end of both files.
         */
        if ((input_scan_count == EOF) &&
            (golden_scan_count == EOF))
        {

            break;
        }

        /*
         * Detect malformed or mismatched files.
         */
        if (input_scan_count != 6)
        {
            fprintf(stderr,
                    "ERROR: Invalid input_data.txt format "
                    "at test %lu\n",
                    total_test_count + 1UL);

            fail_count++;

            break;
        }

        if (golden_scan_count != 1)
        {
            fprintf(stderr,
                    "ERROR: Invalid/missing golden output "
                    "at test %lu\n",
                    total_test_count + 1UL);

            fail_count++;

            break;
        }

        total_test_count++;

        /* --------------------------------------------------------
         * LOAD one data set
         * -------------------------------------------------------- */

        h_accel_load(mmio.ip_reg,
                     a,
                     b,
                     c,
                     d,
                     e,
                     f);

        /* --------------------------------------------------------
         * START accelerator
         * -------------------------------------------------------- */

        h_accel_start(mmio.ip_reg);

        /* --------------------------------------------------------
         * Wait for READ -> COMPUTE -> WRITE
         * -------------------------------------------------------- */

        h_accel_wait_result();

        /* --------------------------------------------------------
         * Read result H
         * -------------------------------------------------------- */

        dut_h =
            h_accel_read_h(mmio.ip_reg);

        /* --------------------------------------------------------
         * Compare against C golden model
         * -------------------------------------------------------- */

        if (dut_h == golden_h)
        {

            pass_count++;

            printf(
                "[PASS] Test %-5lu "
                "DUT=%08" PRIX32 " "
                "GOLDEN=%08" PRIX32 "\n",
                total_test_count,
                dut_h,
                golden_h);
        }
        else
        {

            fail_count++;

            printf(
                "[FAIL] Test %-5lu "
                "DUT=%08" PRIX32 " "
                "GOLDEN=%08" PRIX32 "\n",
                total_test_count,
                dut_h,
                golden_h);

            printf(
                "       "
                "A=%08" PRIX32 " "
                "B=%08" PRIX32 " "
                "C=%08" PRIX32 " "
                "D=%08" PRIX32 " "
                "E=%08" PRIX32 " "
                "F=%08" PRIX32 "\n",
                a,
                b,
                c,
                d,
                e,
                f);
        }
    }

    /* ============================================================
     * Stop accelerator
     * ============================================================ */

    h_accel_stop(mmio.ip_reg);

    /* ============================================================
     * Summary
     * ============================================================ */

    printf("\n");
    printf("============================================================\n");
    printf("                 H_ACCEL TEST SUMMARY\n");
    printf("============================================================\n");

    printf("TOTAL TEST CASES : %lu\n",
           total_test_count);

    printf("PASSED           : %lu\n",
           pass_count);

    printf("FAILED           : %lu\n",
           fail_count);

    printf("------------------------------------------------------------\n");

    if ((fail_count == 0) &&
        (total_test_count > 0))
    {

        printf("FINAL RESULT     : ALL TESTS PASSED\n");
    }
    else
    {

        printf("FINAL RESULT     : TEST FAILED\n");
    }

    printf("============================================================\n");
    printf("\n");

    /* ============================================================
     * Cleanup
     * ============================================================ */

    mmio_close(&mmio);

    fclose(input_file);
    fclose(golden_file);

    if ((fail_count == 0) &&
        (total_test_count > 0))
    {

        return EXIT_SUCCESS;
    }

    return EXIT_FAILURE;
}
