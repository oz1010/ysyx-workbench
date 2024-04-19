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

#include <isa.h>

/* We use the POSIX regex functions to process regular expressions.
 * Type 'man regex' for more information about POSIX regex functions.
 */
#include <regex.h>

#define MIN(_a,_b) ((_a)<(_b)?(_a):(_b))
#if 0
#define TRACE(VAL) printf("Enter %s, token|%d %s val|%d success|%d\n",__FUNCTION__,  *token_idx, *token_idx<nr_token?tokens[*token_idx].str:"NONE", VAL, *success)
#else
#define TRACE(VAL)
#endif
#define TOKEN_EXCEPT() do{\
  Log("token except at %d|%d %s.", *token_idx, tokens[*token_idx].type, tokens[*token_idx].str);\
  *success = false;\
  return 0;\
}while(0)
#define CHECK_SUCCESS() do {if(!*success){return 0;}}while(0)
#define CHECK_TOKEN(N) do{\
  if ((*token_idx+N-1) >= nr_token){\
    Log("token miss %d at %d(max_idx:%d).",(*token_idx+N-1), *token_idx, nr_token-1);\
    *success = false;\
    return 0;\
  }\
}while(0)
#define EXPECT_TOKEN(CHAR) do{\
  CHECK_TOKEN(1);\
  int v = (int)(CHAR);\
  if (tokens[*token_idx].type != v){\
    Log("token expect %d|%c at %d|%s.", v, (CHAR), *token_idx, tokens[*token_idx].str);\
    *success = false;\
    return 0;\
  }\
}while(0)

enum {
  TK_NOTYPE = 256, TK_EQ,

  /* TODO: Add more token types */
  TK_DECNUMBER,
  TK_HEXNUMBER,
  TK_REGVARIABLE,
};

static struct rule {
  const char *regex;
  int token_type;
} rules[] = {

  /* TODO: Add more rules.
   * Pay attention to the precedence level of different rules.
   */

  {" +", TK_NOTYPE},    // spaces
  {"\\+", '+'},         // plus
  {"\\-", '-'},         // minus
  {"\\*", '*'},         // multiply
  {"/", '/'},           // divide
  {"\\(", '('},         // left parenthesis
  {"\\)", ')'},         // right parenthesis
  {"==", TK_EQ},        // equal
  {"==", TK_EQ},        // number

  {"[0-9]+", TK_DECNUMBER},   // decimal number, 123
  {"0x[0-9a-fA-F]+", TK_HEXNUMBER},   // hexadecimal number, 0x125
  {"\\$[a-zA-Z][0-9a-zA-Z]+", TK_REGVARIABLE},   // register variable name, $r0
};

#define NR_REGEX ARRLEN(rules)

static regex_t re[NR_REGEX] = {};

/* Rules are used for many times.
 * Therefore we compile them only once before any usage.
 */
void init_regex() {
  int i;
  char error_msg[128];
  int ret;

  for (i = 0; i < NR_REGEX; i ++) {
    ret = regcomp(&re[i], rules[i].regex, REG_EXTENDED);
    if (ret != 0) {
      regerror(ret, &re[i], error_msg, 128);
      panic("regex compilation failed: %s\n%s", error_msg, rules[i].regex);
    }
  }
}

typedef struct token {
  int type;
  char str[32];
} Token;

static Token tokens[32] __attribute__((used)) = {};
static int nr_token __attribute__((used))  = 0;

static bool make_token(char *e) {
  int position = 0;
  int i;
  regmatch_t pmatch;

  nr_token = 0;

  while (e[position] != '\0') {
    /* Try all rules one by one. */
    for (i = 0; i < NR_REGEX; i ++) {
      if (regexec(&re[i], e + position, 1, &pmatch, 0) == 0 && pmatch.rm_so == 0) {
        char *substr_start = e + position;
        int substr_len = pmatch.rm_eo;

        // Log("match rules[%d] = \"%s\" at position %d with len %d: %.*s",
        //     i, rules[i].regex, position, substr_len, substr_len, substr_start);

        position += substr_len;

        /* TODO: Now a new token is recognized with rules[i]. Add codes
         * to record the token in the array `tokens'. For certain types
         * of tokens, some extra actions should be performed.
         */
        if (nr_token>=sizeof(tokens)/sizeof(tokens[0])){
          Log("Expression is too large.");
          return false;
        }

        switch (rules[i].token_type) {
          case TK_NOTYPE: break;
          case TK_DECNUMBER: 
            tokens[nr_token].type = rules[i].token_type;
            int len = MIN(substr_len, sizeof(tokens[nr_token].str));
            strncpy(tokens[nr_token].str, substr_start, len);
            tokens[nr_token].str[len] = '\0';
            ++nr_token;
            break;
          default: 
            if (rules[i].token_type>=0&&rules[i].token_type<=0xFF) {
              tokens[nr_token].type = rules[i].token_type;
              int len = MIN(substr_len, sizeof(tokens[nr_token].str));
              strncpy(tokens[nr_token].str, substr_start, len);
              tokens[nr_token].str[len] = '\0';
              ++nr_token;
            } else {
              TODO();
            }
        }

        break;
      }
    }

    if (i == NR_REGEX) {
      printf("no match at position %d\n%s\n%*.s^\n", position, e, position, "");
      return false;
    }
  }

  return true;
}

/*
  原始BNF
  <expr> ::= <number>    # 一个数是表达式
  | "(" <expr> ")"     # 在表达式两边加个括号也是表达式
  | <expr> "+" <expr>  # 两个表达式相加也是表达式
  | <expr> "-" <expr>  # 接下来你全懂了
  | <expr> "*" <expr>
  | <expr> "/" <expr>
  1. 消除回溯
  E ::= EL | n | (E)
  L ::= +E | -E | *E | /E
  2. 消除左递归
  E ::= nG | (E)G
  G ::= LG | e
  L ::= *nG | /nG | *E | /E | +E | -E
  */
word_t eval_E(int *token_idx, bool *success);
word_t eval_G(int *token_idx, bool *success, word_t pre_value);

word_t eval_G(int *token_idx, bool *success, word_t pre_value)
{
  TRACE(pre_value);

  // G ::= LG | e
  // L ::= *nG | /nG | *E | /E | +E | -E
  if ((*token_idx) < nr_token){
    word_t val;
    switch(tokens[*token_idx].type){
      case (int)'+': 
        *token_idx+=1;
        val = eval_E(token_idx, success);
        CHECK_SUCCESS();
        return eval_G(token_idx, success, pre_value+val);

      case (int)'-':
        *token_idx+=1;
        val = eval_E(token_idx, success);
        CHECK_SUCCESS();
        return eval_G(token_idx, success, pre_value-val);

      case (int)'*':
        *token_idx+=1;
        // 优先计算
        if (*token_idx<nr_token && tokens[*token_idx].type == TK_DECNUMBER){
          val = strtoul(tokens[*token_idx].str,NULL, 10);
          pre_value *= val;

          *token_idx+=1;
          pre_value = eval_G(token_idx, success, pre_value);
          CHECK_SUCCESS();
        }else{
          val = eval_E(token_idx, success);
          CHECK_SUCCESS();
          pre_value *= val;
        }
        return eval_G(token_idx, success, pre_value);

      case (int)'/':
        *token_idx+=1;
        // 优先计算
        if (*token_idx<nr_token && tokens[*token_idx].type == TK_DECNUMBER){
          val = strtoul(tokens[*token_idx].str,NULL, 10);
          if (val == 0) {
            *success = false;
            Log("divid zero error at %d|%d %s.", *token_idx, tokens[*token_idx].type, tokens[*token_idx].str);
            return 0;
          }
          pre_value /= val;
          
          *token_idx+=1;
          pre_value = eval_G(token_idx, success, pre_value);
          CHECK_SUCCESS();
        }else{
          val = eval_E(token_idx, success);
          CHECK_SUCCESS();
          if (val == 0) {
            *success = false;
            Log("divid zero error at %d|%d %s.", *token_idx, tokens[*token_idx].type, tokens[*token_idx].str);
            return 0;
          }
          pre_value /= val;
        }

        return eval_G(token_idx, success, pre_value);
    }
  }

  return pre_value;
}
word_t eval_E(int *token_idx, bool *success)
{
  TRACE(0);

  CHECK_TOKEN(1);
  
  // E ::= nG | (E)G
  Token *tok = &tokens[*token_idx];
  word_t val = 0;
  switch (tok->type)
  {
  case TK_DECNUMBER:
    val = strtoul(tok->str,NULL, 10);
    *token_idx += 1;
    return eval_G(token_idx, success, val);
  
  case (int)'(':
    *token_idx += 1;
    val = eval_E(token_idx, success);
    CHECK_SUCCESS();
    
    EXPECT_TOKEN(')');
    
    *token_idx += 1;
    return eval_G(token_idx, success, val);
  }

  TOKEN_EXCEPT();
}

word_t expr(char *e, bool *success) {
  if (!make_token(e)) {
    *success = false;
    return 0;
  }

  /* Insert codes to evaluate the expression. */
  int token_idx = 0;
  return eval_E(&token_idx, success);
}
