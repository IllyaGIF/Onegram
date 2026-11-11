#include "Instance.h"

#include <algorithm>
#include <stdio.h>
#include <stdarg.h>
#include <syslog.h>

#include "Ios6DiagnosticLog.h"

namespace tgcalls {
namespace {

std::function<void(std::string const &)> globalLoggingFunction;

std::map<std::string, std::shared_ptr<Meta>> &MetaMap() {
	static auto result = std::map<std::string, std::shared_ptr<Meta>>();
	return result;
}

} // namespace

std::vector<std::string> Meta::Versions() {
	auto &map = MetaMap();
	auto result = std::vector<std::string>();
	result.reserve(map.size());
	for (const auto &entry : map) {
		result.push_back(entry.first);
	}
	return result;
}

int Meta::MaxLayer() {
	auto result = 0;
	for (const auto &entry : MetaMap()) {
		result = std::max(result, entry.second->connectionMaxLayer());
	}
	return result;
}

std::unique_ptr<Instance> Meta::Create(
		const std::string &version,
		Descriptor &&descriptor) {
	OG_COMPAT_TRACE("cxx.meta.create.enter version=%s servers=%lu keyOutgoing=%d",
		version.c_str(),
		(unsigned long)descriptor.rtcServers.size(),
		descriptor.encryptionKey.isOutgoing ? 1 : 0);
	const auto found = MetaMap().find(version);
	OG_COMPAT_TRACE("cxx.meta.create.lookup found=%d mapSize=%lu",
		found != MetaMap().end() ? 1 : 0,
		(unsigned long)MetaMap().size());

	// Enforce correct protocol version.
	if (version == "2.7.7") {
		descriptor.config.protocolVersion = ProtocolVersion::V0;
	} else if (version == "5.0.0") {
		descriptor.config.protocolVersion = ProtocolVersion::V1;
	}

	if (found == MetaMap().end()) {
		OG_COMPAT_TRACE("cxx.meta.create.missing version=%s", version.c_str());
		return nullptr;
	}
	OG_COMPAT_TRACE("cxx.meta.create.construct.before version=%s", version.c_str());
	auto instance = found->second->construct(std::move(descriptor));
	OG_COMPAT_TRACE("cxx.meta.create.construct.after instance=%p", instance.get());
	return instance;
}

void Meta::RegisterOne(std::shared_ptr<Meta> meta) {
	if (meta) {
		const auto versions = meta->versions();
        for (auto &it : versions) {
			OG_COMPAT_TRACE("cxx.meta.register version=%s", it.c_str());
            MetaMap().insert(std::make_pair(it, meta));
        }
	}
}

void SetLoggingFunction(std::function<void(std::string const &)> loggingFunction) {
	globalLoggingFunction = loggingFunction;
}

} // namespace tgcalls
