#ifndef OG_COMPAT_API_ASYNC_DNS_RESOLVER_H
#define OG_COMPAT_API_ASYNC_DNS_RESOLVER_H

namespace webrtc {

class AsyncDnsResolverFactoryInterface {
public:
	virtual ~AsyncDnsResolverFactoryInterface() = default;
};

class BasicAsyncResolverFactory : public AsyncDnsResolverFactoryInterface {
};

} // namespace webrtc

#endif
