#pragma once

#include <cstdint>
#include <unordered_map>
#include <unordered_set>

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
    std::unordered_map<uint8_t, uint64_t> hit_count;   // storage - count
    std::unordered_map<uint8_t, uint64_t> miss_count;  // storage - count
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
        return 0;
    }
};
