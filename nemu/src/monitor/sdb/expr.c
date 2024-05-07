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
#include <macro.h>

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
#define CHECK_TOKEN(IDX, N) do{\
  if ((IDX+N-1) >= nr_token){\
    Log("token miss %d at %d(max_idx:%d).",(IDX+N-1), IDX, nr_token-1);\
    *success = false;\
    return 0;\
  }\
}while(0)
#define EXPECT_TOKEN(IDX, CHAR) do{\
  CHECK_TOKEN(IDX, 1);\
  int v = (int)(CHAR);\
  if (tokens[IDX].type != v){\
    Log("token expect %d|%c at %d|%s.", v, (CHAR), IDX, tokens[IDX].str);\
    *success = false;\
    return 0;\
  }\
}while(0)

enum {
  TK_NOTYPE = 256, TK_EQ,

  /* TODO: Add more token types */
  TK_NEQ,
  TK_DEREF,
  TK_AND,
  TK_DECNUMBER,
  TK_HEXNUMBER,
  TK_REGVARIABLE,
};

typedef struct {
  int type;
  uint32_t priority;
} op_prio_t;

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
  {"!=", TK_NEQ},     // not equal
  {"&&", TK_AND},     // logical and

  {"0x[0-9a-fA-F]+", TK_HEXNUMBER},   // hexadecimal number, 0x125
  {"[0-9]+[U|u]?", TK_DECNUMBER},   // decimal number, 123
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

static Token tokens[3*1024*1024] __attribute__((used)) = {};
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
          case TK_HEXNUMBER:
          case TK_REGVARIABLE:
          case TK_EQ:
          case TK_NEQ:
          case TK_AND:
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

bool eval_variable(Token*tok, word_t*val){

  bool success = false;

  switch (tok->type){
    case TK_DECNUMBER:
    case TK_HEXNUMBER:
      *val = strtoul(tok->str, NULL, tok->type == TK_DECNUMBER ? 10 : 16);
      return true;

    case TK_REGVARIABLE:
      // must be $reg_name
      if (strcmp(tok->str,"$pc")==0) {
        success = true;
        *val = (word_t)cpu.pc;
      }
      else
        *val = isa_reg_str2val(&tok->str[1], &success);
      return success;
  }

  return success;
}

/*
  原始BNF
  <expr> ::= <number>    # 一个数是表达式
  | <hexadecimal-number> # 以0x开头的十六进制数
  | <reg_name>         # 以$开头的寄存器变量
  | "(" <expr> ")"     # 在表达式两边加个括号也是表达式
  | <expr> "+" <expr>  # 两个表达式相加也是表达式
  | <expr> "-" <expr>  # 接下来你全懂了
  | <expr> "*" <expr>
  | <expr> "/" <expr>
  | <expr> "==" <expr>
  | <expr> "!=" <expr>
  | <expr> "&&" <expr>
  1. 消除回溯
  E ::= EL | n | (E)
  L ::= +E | -E | *E | /E | ==E | !=E | &&E
  2. 消除左递归
  E ::= nG | (E)G
  G ::= LG | e
  L ::= *nG | /nG | *E | /E | +E | -E | ==E | !=E | &&E
  */
bool check_parentheses(int begin, int end, bool *success) {  
  int lparenth = 0;
  int rparenth = 0;
  int matched = 0;

  for (int idx = begin; idx<=end; ++idx)
  {
    int type = tokens[idx].type;
    if (type == '('){
      ++lparenth;
    }else if (type == ')'){
      ++rparenth;
    }

    if (lparenth==rparenth)
    {
      ++matched;
    }
  }

  if (lparenth!=rparenth){
    Log("miss match parenteses at %d|'%s' %d|'%s'.", begin, tokens[begin].str, end, tokens[end].str);
    *success=false;
    return 0;
  }

  return tokens[begin].type=='(' && matched == 1;
}

int find_low_op_pos(int begin, int end, bool *success) {
  static op_prio_t op_prios[] = {
    /* type   priority */
    {'*',     6},
    {'/',     6},
    {'+',     7},
    {'-',     7},
    {TK_EQ,   10},
    {TK_NEQ,  10},
    {TK_AND,  14},
  };
  int pos = -1;
  uint32_t priority = 0;

  if (!*success){
    return pos;
  }

  int lparenth = 0;
  int rparenth = 0;
  for (int idx=begin;idx<=end;++idx){
    int type = tokens[idx].type;

    if (type == '('){
      ++lparenth;
    }else if (type == ')'){
      ++rparenth;
    }

    if (lparenth==rparenth)
    {
      // 注意算法优先级
      // 先乘除，后加减
      // 先左后右
      // 找出匹配的最低优先级
      for (int i=0; i<ARRLEN(op_prios); ++i) {
        if (type == op_prios[i].type && priority<= op_prios[i].priority) {
          pos = idx;
          priority = op_prios[i].priority;
          break;
        }
      }
    }
  }

  if (lparenth!=rparenth){
    Log("find op miss match parenteses at %d|'%s' %d|'%s'.", begin, tokens[begin].str, end, tokens[end].str);
    *success=false;
    return 0;
  }

  return pos;
}

word_t eval(int begin, int end, bool *success)
{
  if (begin>end){
    Log("bad expression at %d|'%s' %d|'%s'.", begin, tokens[begin].str, end, tokens[end].str);
    *success = false;
    return 0;
  } else if (begin==end){
    word_t val = 0;
    if (!eval_variable(&tokens[begin], &val)){
      Log("get variable error at %d|'%s'.", begin, tokens[begin].str);
      *success=false;
    }
    return val;
  } else if (check_parentheses(begin, end, success)){
    return eval(begin+1, end-1, success);
  } else {
    int op_pos = find_low_op_pos(begin, end, success);
    if (op_pos<0) {
      *success=false;
      Log("miss low operator pos at %d|'%s' %d|'%s'.", begin, tokens[begin].str, end, tokens[end].str);
      return 0;
    }
    CHECK_SUCCESS();

    word_t val1 = eval(begin, op_pos-1, success);
    word_t val2 = eval(op_pos+1, end, success);

    word_t val = 0;
    switch (tokens[op_pos].type)
    {
      case TK_EQ: val = val1==val2; break;
      case TK_NEQ: val = val1!=val2; break;
      case TK_AND: val = val1&&val2; break;
      case '+': val = val1+val2; break;
      case '-': val = val1-val2; break;
      case '*': val = val1*val2; break;
      case '/': 
        if (val2==0){
          Log("divide by zero error at %d|'%s'.", op_pos, tokens[op_pos].str);
          *success=false;
        }
        val = val1/(val2==0?1:val2);
        break;
      default:
        Log("unknown op error at %d|'%s' %d|'%s'.", begin, tokens[begin].str, end, tokens[end].str);
        *success = false;
        return 0;
    }
    // Log("%uu %s %uu = %u", val1, tokens[op_pos].str, val2, val);
    return val;
  }

  Log("unknown error at %d|'%s' %d|'%s'.", begin, tokens[begin].str, end, tokens[end].str);
  *success = false;
  return 0;
}

word_t expr(char *e, bool *success) {
  if (!(*success = make_token(e))) {
    return 0;
  }

  /* Insert codes to evaluate the expression. */
  // // detect deref
  // for(int i=0;i<nr_token; ++i) {
  //   if (tokens[i].type=='*' && (i==0 || tokens[i-1].type == certain type))
  //     tokens[i].type = TK_DEREF;
  // }

  return eval(0, nr_token-1, success);
}
