#include <string>
#include <fstream>
#include <iostream>
#include <vector>
#include <unordered_map>
#include <iomanip>
#include "cache.h"

using namespace std;

#define show_progress(POS, SIZE)                                                           \
    do                                                                                     \
    {                                                                                      \
        cout << ((POS) == 0 ? "\n" : "\r") << "解析文件进度: " << fixed << setprecision(2) \
             << (100.0 * (POS) / (SIZE)) << "% (" << (POS) << "/" << (SIZE) << ")";        \
        cout.flush();                                                                      \
    } while (0)

ICache *cache;

int parse_binary_file(std::string filepath)
{
    ifstream file(filepath, ios::binary | ios::ate);
    if (!file)
    {
        cerr << "无法打开文件: " << filepath << endl;
        exit(1);
    }

    streamsize size = file.tellg();
    file.seekg(0, ios::beg);
    vector<unsigned char> buffer(size);
    file.read(reinterpret_cast<char *>(buffer.data()), size);
    size_t pos = 0, last_idx = 0, show_mix_size = 1024 * 1024;

    show_progress(pos, size);

    try
    {
        while (pos <= (buffer.size() - 4))
        {
            if (pos - last_idx >= show_mix_size)
            {
                show_progress(pos, size);
                last_idx = pos;
            }
            uint32_t pc = *reinterpret_cast<uint32_t *>(&buffer[pos]);
            cache->find_data(pc);
            pos += 4;
        }
    }
    catch (const std::exception &e)
    {
        std::cerr << e.what() << '\n';
        return -1;
    }

    show_progress(pos, size);

    return 0;
}

int main(int argc, char *argv[])
{
    if (argc < 2)
    {
        cerr << "用法: " << argv[0] << " <日志文件>" << endl;
        return 1;
    }

    cout << "Read file " << argv[1] << endl;

    cache = new CacheFIFO(6);

    int ret = parse_binary_file(argv[1]);
    cache->show_stat();

    return ret;
}
