#ifndef TGCALLS_THREAD_LOCAL_OBJECT_H
#define TGCALLS_THREAD_LOCAL_OBJECT_H

#include "rtc_base/thread.h"

#include <assert.h>
#include <functional>
#include <memory>

namespace tgcalls {

template <typename T>
class ThreadLocalObject {
public:
	template <
		typename Generator,
		typename = std::enable_if_t<std::is_same<std::shared_ptr<T>, decltype(std::declval<Generator>()())>::value>>
	ThreadLocalObject(rtc::Thread *thread, Generator &&generator) :
	_thread(thread),
	_valueHolder(std::make_unique<ValueHolder>()) {
		assert(_thread != nullptr);
		_thread->PostTask(InitTask<Generator>(_valueHolder.get(), std::forward<Generator>(generator)));
	}

	~ThreadLocalObject() {
		_thread->PostTask(ReleaseTask(std::shared_ptr<ValueHolder>(_valueHolder.release())));
	}

	template <typename FunctorT>
	void perform(FunctorT &&functor) {
		_thread->PostTask(PerformTask<FunctorT>(_valueHolder.get(), std::forward<FunctorT>(functor)));
	}

	T *getSyncAssumingSameThread() {
		assert(_thread->IsCurrent());
		assert(_valueHolder->_value);
		return _valueHolder->_value.get();
	}

private:
	struct ValueHolder {
		std::shared_ptr<T> _value;
	};

	template <typename Generator>
	struct InitTask {
		InitTask(ValueHolder *target, Generator &&source) : target(target), source(std::forward<Generator>(source)) {
		}

		void operator()() {
			target->_value = source();
		}

		ValueHolder *target;
		Generator source;
	};

	struct ReleaseTask {
		explicit ReleaseTask(std::shared_ptr<ValueHolder> owner) : owner(owner) {
		}

		void operator()() const {
			owner->_value.reset();
		}

		std::shared_ptr<ValueHolder> owner;
	};

	template <typename FunctorT>
	struct PerformTask {
		PerformTask(ValueHolder *target, FunctorT &&action) : target(target), action(std::forward<FunctorT>(action)) {
		}

		void operator()() {
			assert(target->_value);
			action(target->_value.get());
		}

		ValueHolder *target;
		FunctorT action;
	};

	rtc::Thread *_thread = nullptr;
	std::unique_ptr<ValueHolder> _valueHolder;

};

} // namespace tgcalls

#endif
