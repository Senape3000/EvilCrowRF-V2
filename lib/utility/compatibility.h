#ifndef Compatibility_h
#define Compatibility_h

#include <memory>

// Provide make_unique for pre-C++14 toolchains that lack it.
// Do not redefine if the standard library already provides std::make_unique.
#if __cplusplus < 201402L
namespace std {
template <typename T, typename... Args>
std::unique_ptr<T> make_unique(Args&&... args)
{
    return std::unique_ptr<T>(new T(std::forward<Args>(args)...));
}
}  // namespace std
#endif

#endif