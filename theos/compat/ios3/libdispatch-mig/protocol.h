#ifndef    _libdispatch_internal_protocol_user_
#define    _libdispatch_internal_protocol_user_



#include <string.h>
#include <mach/ndr.h>
#include <mach/boolean.h>
#include <mach/kern_return.h>
#include <mach/notify.h>
#include <mach/mach_types.h>
#include <mach/message.h>
#include <mach/mig_errors.h>
#include <mach/port.h>



#ifndef KERNEL
#if defined(__has_include)
#if __has_include(<mach/mig_voucher_support.h>)
#ifndef USING_VOUCHERS
#define USING_VOUCHERS
#endif
#ifndef __VOUCHER_FORWARD_TYPE_DECLS__
#define __VOUCHER_FORWARD_TYPE_DECLS__
#ifdef __cplusplus
extern "C" {
#endif
    extern boolean_t voucher_mach_msg_set(mach_msg_header_t *msg) __attribute__((weak_import));
#ifdef __cplusplus
}
#endif
#endif
#endif
#endif
#endif






#if defined(__has_include)
#if __has_include(<mach/mig_strncpy_zerofill_support.h>)
#ifndef USING_MIG_STRNCPY_ZEROFILL
#define USING_MIG_STRNCPY_ZEROFILL
#endif
#ifndef __MIG_STRNCPY_ZEROFILL_FORWARD_TYPE_DECLS__
#define __MIG_STRNCPY_ZEROFILL_FORWARD_TYPE_DECLS__
#ifdef __cplusplus
extern "C" {
#endif
    extern int mig_strncpy_zerofill(char *dest, const char *src, int len) __attribute__((weak_import));
#ifdef __cplusplus
}
#endif
#endif
#endif
#endif




#ifdef AUTOTEST
#ifndef FUNCTION_PTR_T
#define FUNCTION_PTR_T
typedef void (*function_ptr_t)(mach_port_t, char *, mach_msg_type_number_t);
typedef struct {
        char            *name;
        function_ptr_t  function;
} function_table_entry;
typedef function_table_entry   *function_table_t;
#endif
#endif

#ifndef    libdispatch_internal_protocol_MSG_COUNT
#define    libdispatch_internal_protocol_MSG_COUNT    16
#endif

#include <mach/std_types.h>
#include <mach/mig.h>
#include <mach/mig.h>
#include <mach/mach_types.h>

#ifdef __BeforeMigUserHeader
__BeforeMigUserHeader
#endif

#include <sys/cdefs.h>
__BEGIN_DECLS



#ifdef    mig_external
mig_external
#else
extern
#endif
kern_return_t _dispatch_send_mach_notify_port_deleted
(
    mach_port_t _notify,
    mach_port_name_t _name
);


#ifdef    mig_external
mig_external
#else
extern
#endif
kern_return_t _dispatch_send_mach_notify_send_possible
(
    mach_port_t _notify,
    mach_port_name_t _name
);


#ifdef    mig_external
mig_external
#else
extern
#endif
kern_return_t _dispatch_send_mach_notify_port_destroyed
(
    mach_port_t _notify,
    mach_port_t _rights
);


#ifdef    mig_external
mig_external
#else
extern
#endif
kern_return_t _dispatch_send_mach_notify_no_senders
(
    mach_port_t _notify,
    mach_port_mscount_t _mscnt
);


#ifdef    mig_external
mig_external
#else
extern
#endif
kern_return_t _dispatch_send_mach_notify_send_once
(
    mach_port_t _notify
);


#ifdef    mig_external
mig_external
#else
extern
#endif
kern_return_t _dispatch_send_mach_notify_dead_name
(
    mach_port_t _notify,
    mach_port_name_t _name
);


#ifdef    mig_external
mig_external
#else
extern
#endif
kern_return_t _dispatch_send_wakeup_main_thread
(
    mach_port_t _port,
    natural_t _waitTimeout
);


#ifdef    mig_external
mig_external
#else
extern
#endif
kern_return_t _dispatch_send_consume_send_once_right
(
    mach_port_t _port
);

__END_DECLS














#ifndef __Request__libdispatch_internal_protocol_subsystem__defined
#define __Request__libdispatch_internal_protocol_subsystem__defined

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        mach_port_name_t _name;
    } __Request__mach_notify_port_deleted_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        mach_port_name_t _name;
    } __Request__mach_notify_send_possible_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;

        mach_msg_body_t msgh_body;
        mach_msg_port_descriptor_t _rights;

    } __Request__mach_notify_port_destroyed_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        mach_port_mscount_t _mscnt;
    } __Request__mach_notify_no_senders_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
    } __Request__mach_notify_send_once_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        mach_port_name_t _name;
    } __Request__mach_notify_dead_name_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
    } __Request__wakeup_main_thread_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
    } __Request__consume_send_once_right_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
#endif



#ifndef __RequestUnion___dispatch_send_libdispatch_internal_protocol_subsystem__defined
#define __RequestUnion___dispatch_send_libdispatch_internal_protocol_subsystem__defined
union __RequestUnion___dispatch_send_libdispatch_internal_protocol_subsystem {
    __Request__mach_notify_port_deleted_t Request__dispatch_send_mach_notify_port_deleted;
    __Request__mach_notify_send_possible_t Request__dispatch_send_mach_notify_send_possible;
    __Request__mach_notify_port_destroyed_t Request__dispatch_send_mach_notify_port_destroyed;
    __Request__mach_notify_no_senders_t Request__dispatch_send_mach_notify_no_senders;
    __Request__mach_notify_send_once_t Request__dispatch_send_mach_notify_send_once;
    __Request__mach_notify_dead_name_t Request__dispatch_send_mach_notify_dead_name;
    __Request__wakeup_main_thread_t Request__dispatch_send_wakeup_main_thread;
    __Request__consume_send_once_right_t Request__dispatch_send_consume_send_once_right;
};
#endif


#ifndef __Reply__libdispatch_internal_protocol_subsystem__defined
#define __Reply__libdispatch_internal_protocol_subsystem__defined

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
    } __Reply__mach_notify_port_deleted_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
    } __Reply__mach_notify_send_possible_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
    } __Reply__mach_notify_port_destroyed_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
    } __Reply__mach_notify_no_senders_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
    } __Reply__mach_notify_send_once_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
    } __Reply__mach_notify_dead_name_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
    } __Reply__wakeup_main_thread_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        kern_return_t RetCode;
    } __Reply__consume_send_once_right_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
#endif



#ifndef __ReplyUnion___dispatch_send_libdispatch_internal_protocol_subsystem__defined
#define __ReplyUnion___dispatch_send_libdispatch_internal_protocol_subsystem__defined
union __ReplyUnion___dispatch_send_libdispatch_internal_protocol_subsystem {
    __Reply__mach_notify_port_deleted_t Reply__dispatch_send_mach_notify_port_deleted;
    __Reply__mach_notify_send_possible_t Reply__dispatch_send_mach_notify_send_possible;
    __Reply__mach_notify_port_destroyed_t Reply__dispatch_send_mach_notify_port_destroyed;
    __Reply__mach_notify_no_senders_t Reply__dispatch_send_mach_notify_no_senders;
    __Reply__mach_notify_send_once_t Reply__dispatch_send_mach_notify_send_once;
    __Reply__mach_notify_dead_name_t Reply__dispatch_send_mach_notify_dead_name;
    __Reply__wakeup_main_thread_t Reply__dispatch_send_wakeup_main_thread;
    __Reply__consume_send_once_right_t Reply__dispatch_send_consume_send_once_right;
};
#endif

#ifndef subsystem_to_name_map_libdispatch_internal_protocol
#define subsystem_to_name_map_libdispatch_internal_protocol \
    { "mach_notify_port_deleted", 65 },\
    { "mach_notify_send_possible", 66 },\
    { "mach_notify_port_destroyed", 69 },\
    { "mach_notify_no_senders", 70 },\
    { "mach_notify_send_once", 71 },\
    { "mach_notify_dead_name", 72 },\
    { "wakeup_main_thread", 78 },\
    { "consume_send_once_right", 79 }
#endif

#ifdef __AfterMigUserHeader
__AfterMigUserHeader
#endif

#endif
