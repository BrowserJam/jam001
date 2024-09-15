add_library(std STATIC)
target_sources(std
  PRIVATE
    Arena.c Arena.h
    Check.c Check.h
    Chronometry.c Chronometry.h
    Hash.c Hash.h
    Utils.cpp Utils.hpp
    vec.c vec.h
)
target_link_libraries(std PRIVATE log)