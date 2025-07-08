#pragma once

#include <cstdint>
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
    virtual int find_data(uint32_t pc) = 0;
    virtual void show_stat()
    {
        uint64_t total_hit_count = 0;
        uint64_t total_miss_count = 0;
        std::cout << "缓存统计:\n";
        for (auto &[mem_idx, hit_count] : hit_counts)
        {
            auto miss_count = miss_counts[mem_idx];
            double p = hit_count * 1.0 / (hit_count + miss_count);
            total_hit_count += hit_count;
            total_miss_count += miss_count;
            cout << setw(8) << mem_idx_2_str(mem_idx) << ": " << fixed << setprecision(1) << p * 100
                 << "% (" << hit_count << " " << (hit_count + miss_count) << ")" << std::endl;
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
    }

    ~CacheFIFO()
    {
    }

    int find_data(uint32_t pc) override
    {
        int mem_idx = in_mem(pc);
        if (mem_idx < 0)
            return 0;

        uint32_t tag = GET_BITS(pc, m + n, 32 - (m + n));
        // uint32_t index = GET_BITS(pc, m, n);
        if (tags.find(tag) != tags.end())
        {
            // 命中缓存
            ++hit_counts[mem_idx];
            return 1;
        }
        else
        {
            // 未命中缓存
            ++miss_counts[mem_idx];
            tags.clear();
            tags.insert(tag);
            return 2;
        }
        return 0;
    }
};
