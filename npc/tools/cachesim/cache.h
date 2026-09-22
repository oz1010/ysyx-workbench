#pragma once

#include <cstdint>
#include <cstdlib>
#include <ios>
#include <unordered_map>
#include <unordered_set>
#include <iostream>
#include <iomanip>
#include <vector>
#include "bits.h"
#include "mem.h"

using namespace std;

/*
每个组中有w个cache块
n = log2(cache块总数/w)
31    m+n m+n-1   m m-1    0
+---------+---------+--------+
|   tag   |  index  | offset |
+---------+---------+--------+
*/

typedef struct
{
    bool v;
    uint32_t tag;
    // uint32_t data;
    uint64_t flag;
} cache_line_t;

typedef struct
{
    bool silence;
} cache_cfg_t;

class ICache
{
   protected:
    std::unordered_map<uint32_t, uint32_t> lines;  // tag - arg
    std::unordered_set<uint32_t> tags;
    std::vector<std::vector<cache_line_t>> groups;
    cache_line_t* matched_line;
    std::unordered_map<uint8_t, uint64_t> hit_counts;   // storage - count
    std::unordered_map<uint8_t, uint64_t> miss_counts;  // storage - count
    uint64_t count;
    const uint32_t w;
    const uint32_t n;
    const uint32_t m;
    const cache_cfg_t cfg;

   public:
    ICache(uint32_t w, uint32_t n, uint32_t m, cache_cfg_t cfg)
        : w(w),
          n(n),
          m(m),
          cfg(cfg)
    {
        uint32_t group_size = 1 << this->n;
        uint32_t line_size = 1 << this->m;
        groups = {};
        groups.resize(group_size);
        for (size_t index = 0; index < group_size; ++index)
        {
            auto& group = groups[index];
            group = {};
            group.resize(this->w);
            for (auto& line : group)
            {
                line = {false, 0};
            }
        }

        // lines.insert(std::pair<uint32_t, uint32_t>(0, 0));
        // lines.find(0) != lines.end();
        // lines.erase(0);
        // tags.insert(0);
        // tags.find(0) != tags.end();
        // tags.erase(0);
        // ios_base::fmtflags def_fmt = cout.flags();
        // cout << hex << "BIT_MASK(1): " << BIT_MASK(1) << endl;
        // cout << hex << "BIT_MASK(16): " << BIT_MASK(16) << endl;
        // cout << hex << "BIT_MASK(30): " << BIT_MASK(30) << endl;
        // cout.flags(def_fmt);
        if (!cfg.silence)
        {
            cout << "缓存基本参数：\n";
            cout << "tag: [" << (31) << ", " << (this->m + this->n) << "]" << endl;
            if (this->n)
                cout << "index: [" << (this->m + this->n - 1) << ", " << (this->m) << "]" << endl;
            else
                cout << "index: none" << endl;
            cout << "offset: [" << (this->m + -1) << ", " << (0) << "]" << endl;
            cout << "组中行数量: " << this->w << endl;
            cout << "缓存组数量: " << group_size << "" << endl;
            cout << "缓存行大小: " << line_size << endl;
            cout << "总大小: " << (this->w * group_size * line_size) << endl;
            show_mem_time();
        }
    }
    virtual int hit_data(uint32_t tag, uint32_t index, int mem_idx)
    {
        return 0;
    };
    virtual int miss_data(uint32_t tag, uint32_t index, int mem_idx)
    {
        return 0;
    };
    virtual int find_data(uint32_t pc)
    {
        ++count;
        int mem_idx = in_mem(pc);
        if (mem_idx < 0)
            return 0;

        uint32_t tag = GET_BITS(pc, m + n, 32 - (m + n));
        uint32_t index = n > 0 ? GET_BITS(pc, m, n) : 0;
        auto& group = groups[index];
        matched_line = nullptr;

        for (auto& line : group)
        {
            if (line.v && line.tag == tag)
            {
                matched_line = &line;
                break;
            }
        }

        if (matched_line)
        {
            // 命中缓存
            hit_counts[mem_idx] += 1;
            miss_counts[mem_idx] += 0;
            matched_line->flag = count;
            return hit_data(tag, index, mem_idx);
        }
        else
        {
            // 未命中缓存
            hit_counts[mem_idx] += 0;
            miss_counts[mem_idx] += 1;
            return miss_data(tag, index, mem_idx);
        }
    }
    virtual void show_stat()
    {
        uint64_t total_hit_count = 0;
        uint64_t total_miss_count = 0;
        std::cout << "\n指令缓存统计:\n";
        for (auto& [mem_idx, hit_count] : hit_counts)
        {
            auto miss_count = miss_counts[mem_idx];
            total_hit_count += hit_count;
            total_miss_count += miss_count;
            /* ref.
             * https://ysyx.oscc.cc/docs/2306/basic/1.9.html#%E7%BC%93%E5%AD%98%E7%9A%84%E4%BC%98%E5%8C%96
             */
            auto& mem_info = get_mem_info(mem_idx);
            double access_time = mem_info.access_time;
            double miss_penalty = mem_info.miss_penalty;
            double p = hit_count * 1.0 / (hit_count + miss_count);
            double amat = access_time + (1 - p) * miss_penalty;
            /* FIXME 假定数据位宽为32 */
            double load_cache_count = this->m < 2 ? 1 : (1 << (this->m - 2));
            double tmt = miss_count * (miss_penalty * load_cache_count);
            cout << setw(8) << mem_idx_2_str(mem_idx) << " count: " << fixed << setprecision(1)
                 << p * 100 << "% (" << hit_count << " " << (hit_count + miss_count) << ")"
                 << std::endl;
            cout << setw(8) << mem_idx_2_str(mem_idx) << " AMAT: " << fixed << setprecision(1)
                 << amat << " (" << access_time << " " << miss_penalty << ")" << endl;
            cout << setw(8) << mem_idx_2_str(mem_idx) << " TMT: " << fixed << setprecision(1) << tmt
                 << endl;
        }
        {
            double p = total_hit_count * 1.0 / (total_hit_count + total_miss_count);
            cout << "合计count"
                 << ": " << fixed << setprecision(1) << p * 100 << "% (" << total_hit_count << " "
                 << (total_hit_count + total_miss_count) << ")" << std::endl;
        }
    }
    virtual ~ICache() = default;
};

class CacheFIFO : public ICache
{
   public:
    CacheFIFO(uint32_t w, uint32_t n, uint32_t m, cache_cfg_t cfg)
        : ICache(w, n, m, cfg)
    {
    }

    ~CacheFIFO()
    {
    }

    int hit_data(uint32_t tag, uint32_t index, int mem_idx) override
    {
        return 0;
    };
    int miss_data(uint32_t tag, uint32_t index, int mem_idx) override
    {
        auto& group = groups[index];
        matched_line = &group[0];
        uint64_t min = matched_line->flag;

        for (auto& line : group)
        {
            if (line.flag < min)
            {
                matched_line = &line;
                break;
            }
        }
        matched_line->v = true;
        matched_line->tag = tag;
        matched_line->flag = count;
        return 0;
    };
};
