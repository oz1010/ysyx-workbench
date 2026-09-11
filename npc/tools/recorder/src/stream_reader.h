#ifndef __STREAM_READER_H__
#define __STREAM_READER_H__

#include <cstring>
#include <fstream>
#include <string>
#include <vector>

namespace recorder
{

/**
 * 分页流式读取器：每次最多读取page_size字节到内存，
 * 缓冲数据不足时先压缩剩余数据再读入下一页
 */
class StreamReader
{
public:
    int open(const std::string& path, size_t page_size, std::string& err)
    {
        if (page_size == 0)
        {
            err = "page大小不能为0";
            return -1;
        }
        ifs_.open(path, std::ios::binary);
        if (!ifs_)
        {
            err = "无法打开文件: " + path;
            return -1;
        }
        buf_.resize(page_size);
        return 0;
    }

    /**
     * 确保缓冲区内至少有n字节可读，不足时读入下一页
     * @return true: 足够, false: 文件结束且剩余数据不足
     */
    bool require(size_t n)
    {
        if (n > buf_.size())
        {
            // 单字段长度不可能超过缓冲区，预留防御
            while (buf_.size() < n)
            {
                buf_.resize(buf_.size() * 2);
            }
        }
        while (end_ - pos_ < n)
        {
            if (eof_) return false;
            compact();
            ifs_.read(reinterpret_cast<char*>(buf_.data() + end_),
                      static_cast<std::streamsize>(buf_.size() - end_));
            end_ += static_cast<size_t>(ifs_.gcount());
            if (ifs_.eof())
            {
                eof_ = true;
                ifs_.clear();
            }
        }
        return end_ - pos_ >= n;
    }

    uint8_t read_u8()
    {
        uint8_t v = buf_[pos_++];
        base_++;
        return v;
    }

    /**
     * ULEB128变长读取，最多10字节，超出视为数据错误
     */
    bool read_uleb128(uint64_t* val)
    {
        uint64_t result = 0;
        for (int i = 0; i < 10; ++i)
        {
            if (!require(1)) return false;
            uint8_t byte = read_u8();
            if (i == 9 && (byte & 0x80))
            {
                err_overflow_ = true;
                return false;
            }
            result |= static_cast<uint64_t>(byte & 0x7F) << (7 * i);
            if (!(byte & 0x80)) break;
        }
        *val = result;
        return true;
    }

    /**
     * 读取定长数据
     */
    bool read_bytes(void* dst, size_t n)
    {
        if (!require(n)) return false;
        std::memcpy(dst, buf_.data() + pos_, n);
        pos_ += n;
        base_ += n;
        return true;
    }

    uint64_t tell() const { return base_; }
    bool     uleb_overflow() const { return err_overflow_; }

private:
    void compact()
    {
        if (pos_ > 0)
        {
            std::memmove(buf_.data(), buf_.data() + pos_, end_ - pos_);
            end_ -= pos_;
            pos_  = 0;
        }
    }

    std::ifstream        ifs_;
    std::vector<uint8_t> buf_;
    size_t               pos_          = 0;  // 读位置
    size_t               end_          = 0;  // 有效数据末尾
    uint64_t             base_         = 0;  // buf_[pos_]对应的文件偏移
    bool                 eof_          = false;
    bool                 err_overflow_ = false;
};

}  // namespace recorder

#endif
