#pragma once

#include <cstdint>
#include <unordered_map>
#include <unordered_set>

class ICache
{
   protected:
    std::unordered_map<uint32_t, uint32_t> lines;  // tag - arg
    std::unordered_set<uint32_t> tags;
    std::unordered_map<uint8_t, uint64_t> hit_count;   // storage - count
    std::unordered_map<uint8_t, uint64_t> miss_count;  // storage - count

   public:
    virtual int find_data(uint32_t pc) = 0;
    virtual void show_stat()
    {
    }
    virtual ~ICache() = default;
};

class CacheFIFO : public ICache
{
   private:
   public:
    CacheFIFO();
    ~CacheFIFO();
    int find_data(uint32_t pc) override
    {
        return 0;
    }
};

CacheFIFO::CacheFIFO()
{
    lines.insert(std::pair<uint32_t, uint32_t>(0, 0));
    lines.find(0) != lines.end();
    lines.erase(0);
    tags.insert(0);
    tags.find(0) != tags.end();
    tags.erase(0);
}

CacheFIFO::~CacheFIFO()
{
}
