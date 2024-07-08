#ifndef __POINT_POOL_H__
#define __POINT_POOL_H__

typedef enum {
  POINT_UNKNOWN,
  POINT_BREAK,
  POINT_WATCH,
  POINT_ALL,
} point_type_t;

void init_point_pool();
void add_point(point_type_t type, char *str);
void delete_point(uint64_t id);
void show_point(point_type_t type);
bool scan_point(point_type_t type);

#endif
