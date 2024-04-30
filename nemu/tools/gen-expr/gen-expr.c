/***************************************************************************************
 * Copyright (c) 2014-2022 Zihao Yu, Nanjing University
 *
 * NEMU is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *          http://license.coscl.org.cn/MulanPSL2
 *
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 *
 * See the Mulan PSL v2 for more details.
 ***************************************************************************************/

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>
#include <string.h>
#include <stdarg.h>

// this should be enough
static char buf[65536] = {};
static int buf_idx = 0;
static char code_buf[65536 + 128] = {};  // a little larger than `buf`
static char *code_format =
    "#include <stdio.h>\n"
    "int main() { "
    "  unsigned result = %s; "
    "  printf(\"%%u\", result); "
    "  return 0; "
    "}";
uint32_t max_depth = 20;
uint32_t cur_depth = 0;
uint32_t max_single_num = 1000;

uint32_t choose(uint32_t num)
{
    return random() % num;
}
uint32_t showBuf(uint32_t idx, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    uint32_t ret = vsnprintf(&buf[idx], sizeof(buf) - idx, fmt, ap);
    va_end(ap);

    return ret;
}

void gen_num()
{
    uint32_t num = choose(max_single_num);
    buf_idx += showBuf(buf_idx, "%uu", num);
}
void gen(char c)
{
    buf_idx += showBuf(buf_idx, "%c", c);
}
char gen_rand_op(uint32_t idx, uint32_t max_num)
{
    char ops[] = {'+', '-', '*', '/'};
    uint32_t ops_idx = choose(max_num);
    return ops[ops_idx];
}

static void gen_rand_expr()
{
    char last_c = '\0';
    int last_buf_idx = 0;

    ++cur_depth;
    if (cur_depth == 1)
    {
        buf[0] = '\0';
        buf_idx = 0;
    }

    if (cur_depth > max_depth)
    {
        gen_num();
    }
    else
    {
        uint32_t idx = choose(3);
        switch (idx)
        {
            case 0:
                gen_num();
                break;
            case 1:
                gen('(');
                gen_rand_expr();
                gen(')');
                break;
            default:
                gen_rand_expr();
                last_buf_idx = buf_idx++;
                last_c = gen_rand_op(last_buf_idx, 4);
                buf[last_buf_idx] = last_c;
                gen_rand_expr();
                break;
        }
    }
    // if (cur_depth == 1)
    // buf_idx += snprintf(&buf[buf_idx], sizeof(buf) - buf_idx, "\n");
    --cur_depth;
}

int main(int argc, char *argv[])
{
#if 1
    FILE*fd=fopen("/dev/random", "r");
    assert(fd);
    char c;
    size_t size = fread(&c, 1, 1, fd);
    assert(size>0);
    fclose(fd);
    int seed = time(0) + c;
#else
    int seed = 1714443307;
#endif
    srand(seed);
    int loop = 1;
    fprintf(stderr, "current seed = %d\n", seed);
    if (argc > 1)
    {
        sscanf(argv[1], "%d", &loop);
    }
    int i;
    for (i = 0; i < loop; i++)
    {
        gen_rand_expr();

        sprintf(code_buf, code_format, buf);

        FILE *fp = fopen("/tmp/.code.c", "w");
        assert(fp != NULL);
        fputs(code_buf, fp);
        fclose(fp);

        int ret = system("gcc /tmp/.code.c -Werror -o /tmp/.expr 2>/dev/null");
        if (ret != 0)
        {
            --i;
            continue;
        }

        fp = popen("/tmp/.expr", "r");
        assert(fp != NULL);

        int result;
        ret = fscanf(fp, "%d", &result);
        pclose(fp);

        printf("%u %s\n", result, buf);
    }
    return 0;
}
