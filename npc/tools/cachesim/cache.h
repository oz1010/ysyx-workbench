#pragma once

#include <cstdint>
#include <ios>
#include <unordered_map>
#include <unordered_set>
#include <iostream>
#include <iomanip>
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

class ICache
{
   protected:
    std::unordered_map<uint32_t, uint32_t> lines;  // tag - arg
    std::unordered_set<uint32_t> tags;
    std::unordered_map<uint8_t, uint64_t> hit_counts;   // storage - count
    std::unordered_map<uint8_t, uint64_t> miss_counts;  // storage - count
    uint32_t m;
    uint32_t n;
    uint32_t w;

   public:
    ICache(uint32_t n, uint32_t m, uint32_t w)
    {
        this->n = n;
        this->m = m;
        this->w = w;
    }
    virtual int hit_data(uint32_t tag, int mem_idx)
    {
        return 0;
    };
    virtual int miss_data(uint32_t tag, int mem_idx)
    {
        return 0;
    };
    virtual int find_data(uint32_t pc)
    {
        int mem_idx = in_mem(pc);
        if (mem_idx < 0)
            return 0;

        uint32_t tag = GET_BITS(pc, m + n, 32 - (m + n));
        if (tags.find(tag) != tags.end())
        {
            // 命中缓存
            ++hit_counts[mem_idx];
            return hit_data(tag, mem_idx);
        }
        else
        {
            // 未命中缓存
            ++miss_counts[mem_idx];
            return miss_data(tag, mem_idx);
        }
    }
    virtual void show_stat()
    {
        uint64_t total_hit_count = 0;
        uint64_t total_miss_count = 0;
        std::cout << "缓存统计:\n";
        for (auto &[mem_idx, hit_count] : hit_counts)
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
            cout << setw(8) << mem_idx_2_str(mem_idx) << ": " << fixed << setprecision(1) << p * 100
                 << "% (" << hit_count << " " << (hit_count + miss_count) << ")" << std::endl;
            cout << setw(8) << ""
                 << "  " << fixed << setprecision(1) << amat << " (" << access_time << " "
                 << miss_penalty << ")" << endl;
        }
        {
            double p = total_hit_count * 1.0 / (total_hit_count + total_miss_count);
            cout << "合计"
                 << ": " << fixed << setprecision(1) << p * 100 << "% (" << total_hit_count << " "
                 << (total_hit_count + total_miss_count) << ")" << std::endl;
        }
    }
    virtual ~ICache() = default;
};

class CacheFIFO : public ICache
{
   public:
    CacheFIFO(uint32_t n, uint32_t m = 2, uint32_t w = 1)
        : ICache(n, m, w)
    {
        // lines.insert(std::pair<uint32_t, uint32_t>(0, 0));
        // lines.find(0) != lines.end();
        // lines.erase(0);
        // tags.insert(0);
        // tags.find(0) != tags.end();
        // tags.erase(0);
        ios_base::fmtflags def_fmt = cout.flags();
        // cout << hex << "BIT_MASK(1): " << BIT_MASK(1) << endl;
        // cout << hex << "BIT_MASK(16): " << BIT_MASK(16) << endl;
        // cout << hex << "BIT_MASK(30): " << BIT_MASK(30) << endl;
        cout.flags(def_fmt);
        cout << "缓存基本参数：\n";
        cout << "n:" << n << endl;
        cout << "m:" << m << endl;
        cout << "w:" << w << endl;
        show_mem_time();
    }

    ~CacheFIFO()
    {
    }

    int hit_data(uint32_t tag, int mem_idx) override
    {
        return 0;
    };
    int miss_data(uint32_t tag, int mem_idx) override
    {
        tags.clear();
        tags.insert(tag);
        return 0;
    };
};
