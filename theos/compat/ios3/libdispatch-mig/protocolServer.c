








#define    __MIG_check__Request__libdispatch_internal_protocol_subsystem__ 1

#include "protocolServer.h"

#ifndef    mig_internal
#define    mig_internal    static __inline__
#endif

#ifndef    mig_external
#define mig_external
#endif

#if    !defined(__MigTypeCheck) && defined(TypeCheck)
#define    __MigTypeCheck        TypeCheck
#endif

#if    !defined(__MigKernelSpecificCode) && defined(_MIG_KERNEL_SPECIFIC_CODE_)
#define    __MigKernelSpecificCode    _MIG_KERNEL_SPECIFIC_CODE_
#endif

#ifndef    LimitCheck
#define    LimitCheck 0
#endif

#ifndef    min
#define    min(a,b)  ( ((a) < (b))? (a): (b) )
#endif

#if !defined(_WALIGN_)
#define _WALIGN_(x) (((x) + 3) & ~3)
#endif

#if !defined(_WALIGNSZ_)
#define _WALIGNSZ_(x) _WALIGN_(sizeof(x))
#endif

#ifndef    UseStaticTemplates
#define    UseStaticTemplates    0
#endif

#ifndef MIG_SERVER_ROUTINE
#define MIG_SERVER_ROUTINE
#endif

#ifndef    __DeclareRcvRpc
#define    __DeclareRcvRpc(_NUM_, _NAME_)
#endif

#ifndef    __BeforeRcvRpc
#define    __BeforeRcvRpc(_NUM_, _NAME_)
#endif

#ifndef    __AfterRcvRpc
#define    __AfterRcvRpc(_NUM_, _NAME_)
#endif

#ifndef    __DeclareRcvSimple
#define    __DeclareRcvSimple(_NUM_, _NAME_)
#endif

#ifndef    __BeforeRcvSimple
#define    __BeforeRcvSimple(_NUM_, _NAME_)
#endif

#ifndef    __AfterRcvSimple
#define    __AfterRcvSimple(_NUM_, _NAME_)
#endif

#define novalue void

#define msgh_request_port    msgh_local_port
#define MACH_MSGH_BITS_REQUEST(bits)    MACH_MSGH_BITS_LOCAL(bits)
#define msgh_reply_port        msgh_remote_port
#define MACH_MSGH_BITS_REPLY(bits)    MACH_MSGH_BITS_REMOTE(bits)

#define MIG_RETURN_ERROR(X, code)    {\
                ((mig_reply_error_t *)X)->RetCode = code;\
                ((mig_reply_error_t *)X)->NDR = NDR_record;\
                return;\
                }




mig_internal novalue _Xmach_notify_port_deleted
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);

mig_internal novalue _Xmach_notify_send_possible
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);

mig_internal novalue _Xmach_notify_port_destroyed
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);

mig_internal novalue _Xmach_notify_no_senders
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);

mig_internal novalue _Xmach_notify_send_once
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);

mig_internal novalue _Xmach_notify_dead_name
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);

mig_internal novalue _Xwakeup_main_thread
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);

mig_internal novalue _Xconsume_send_once_right
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);


#if ( __MigTypeCheck )
#if __MIG_check__Request__libdispatch_internal_protocol_subsystem__
#if !defined(__MIG_check__Request__mach_notify_port_deleted_t__defined)
#define __MIG_check__Request__mach_notify_port_deleted_t__defined

mig_internal kern_return_t __MIG_check__Request__mach_notify_port_deleted_t(__attribute__((__unused__)) __Request__mach_notify_port_deleted_t *In0P)
{

    typedef __Request__mach_notify_port_deleted_t __Request;
#if    __MigTypeCheck
    if ((In0P->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) ||
        (In0P->Head.msgh_size != (mach_msg_size_t)sizeof(__Request)))
        return MIG_BAD_ARGUMENTS;
#endif

    return MACH_MSG_SUCCESS;
}
#endif
#endif
#endif



mig_internal novalue _Xmach_notify_port_deleted
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP)
{

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        mach_port_name_t _name;
        mach_msg_trailer_t trailer;
    } Request __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
    typedef __Request__mach_notify_port_deleted_t __Request;
    typedef __Reply__mach_notify_port_deleted_t Reply __attribute__((unused));









    Request *In0P = (Request *) InHeadP;
    Reply *OutP = (Reply *) OutHeadP;
#ifdef    __MIG_check__Request__mach_notify_port_deleted_t__defined
    kern_return_t check_result;
#endif

    __DeclareRcvSimple(65, "mach_notify_port_deleted")
    __BeforeRcvSimple(65, "mach_notify_port_deleted")

#if    defined(__MIG_check__Request__mach_notify_port_deleted_t__defined)
    check_result = __MIG_check__Request__mach_notify_port_deleted_t((__Request *)In0P);
    if (check_result != MACH_MSG_SUCCESS)
        { MIG_RETURN_ERROR(OutP, check_result); }
#endif

    OutP->RetCode = _dispatch_mach_notify_port_deleted(In0P->Head.msgh_request_port, In0P->_name);
    __AfterRcvSimple(65, "mach_notify_port_deleted")
}

#if ( __MigTypeCheck )
#if __MIG_check__Request__libdispatch_internal_protocol_subsystem__
#if !defined(__MIG_check__Request__mach_notify_send_possible_t__defined)
#define __MIG_check__Request__mach_notify_send_possible_t__defined

mig_internal kern_return_t __MIG_check__Request__mach_notify_send_possible_t(__attribute__((__unused__)) __Request__mach_notify_send_possible_t *In0P)
{

    typedef __Request__mach_notify_send_possible_t __Request;
#if    __MigTypeCheck
    if ((In0P->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) ||
        (In0P->Head.msgh_size != (mach_msg_size_t)sizeof(__Request)))
        return MIG_BAD_ARGUMENTS;
#endif

    return MACH_MSG_SUCCESS;
}
#endif
#endif
#endif



mig_internal novalue _Xmach_notify_send_possible
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP)
{

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        mach_port_name_t _name;
        mach_msg_trailer_t trailer;
    } Request __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
    typedef __Request__mach_notify_send_possible_t __Request;
    typedef __Reply__mach_notify_send_possible_t Reply __attribute__((unused));









    Request *In0P = (Request *) InHeadP;
    Reply *OutP = (Reply *) OutHeadP;
#ifdef    __MIG_check__Request__mach_notify_send_possible_t__defined
    kern_return_t check_result;
#endif

    __DeclareRcvSimple(66, "mach_notify_send_possible")
    __BeforeRcvSimple(66, "mach_notify_send_possible")

#if    defined(__MIG_check__Request__mach_notify_send_possible_t__defined)
    check_result = __MIG_check__Request__mach_notify_send_possible_t((__Request *)In0P);
    if (check_result != MACH_MSG_SUCCESS)
        { MIG_RETURN_ERROR(OutP, check_result); }
#endif

    OutP->RetCode = _dispatch_mach_notify_send_possible(In0P->Head.msgh_request_port, In0P->_name);
    __AfterRcvSimple(66, "mach_notify_send_possible")
}

#if ( __MigTypeCheck )
#if __MIG_check__Request__libdispatch_internal_protocol_subsystem__
#if !defined(__MIG_check__Request__mach_notify_port_destroyed_t__defined)
#define __MIG_check__Request__mach_notify_port_destroyed_t__defined

mig_internal kern_return_t __MIG_check__Request__mach_notify_port_destroyed_t(__attribute__((__unused__)) __Request__mach_notify_port_destroyed_t *In0P)
{

    typedef __Request__mach_notify_port_destroyed_t __Request;
#if    __MigTypeCheck
    if (!(In0P->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) ||
        (In0P->msgh_body.msgh_descriptor_count != 1) ||
        (In0P->Head.msgh_size != (mach_msg_size_t)sizeof(__Request)))
        return MIG_BAD_ARGUMENTS;
#endif

#if    __MigTypeCheck
    if (In0P->_rights.type != MACH_MSG_PORT_DESCRIPTOR ||
        In0P->_rights.disposition != 16)
        return MIG_TYPE_ERROR;
#endif

    return MACH_MSG_SUCCESS;
}
#endif
#endif
#endif



mig_internal novalue _Xmach_notify_port_destroyed
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP)
{

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;

        mach_msg_body_t msgh_body;
        mach_msg_port_descriptor_t _rights;

        mach_msg_trailer_t trailer;
    } Request __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
    typedef __Request__mach_notify_port_destroyed_t __Request;
    typedef __Reply__mach_notify_port_destroyed_t Reply __attribute__((unused));









    Request *In0P = (Request *) InHeadP;
    Reply *OutP = (Reply *) OutHeadP;
#ifdef    __MIG_check__Request__mach_notify_port_destroyed_t__defined
    kern_return_t check_result;
#endif

    __DeclareRcvSimple(69, "mach_notify_port_destroyed")
    __BeforeRcvSimple(69, "mach_notify_port_destroyed")

#if    defined(__MIG_check__Request__mach_notify_port_destroyed_t__defined)
    check_result = __MIG_check__Request__mach_notify_port_destroyed_t((__Request *)In0P);
    if (check_result != MACH_MSG_SUCCESS)
        { MIG_RETURN_ERROR(OutP, check_result); }
#endif

    OutP->RetCode = _dispatch_mach_notify_port_destroyed(In0P->Head.msgh_request_port, In0P->_rights.name);
    __AfterRcvSimple(69, "mach_notify_port_destroyed")
}

#if ( __MigTypeCheck )
#if __MIG_check__Request__libdispatch_internal_protocol_subsystem__
#if !defined(__MIG_check__Request__mach_notify_no_senders_t__defined)
#define __MIG_check__Request__mach_notify_no_senders_t__defined

mig_internal kern_return_t __MIG_check__Request__mach_notify_no_senders_t(__attribute__((__unused__)) __Request__mach_notify_no_senders_t *In0P)
{

    typedef __Request__mach_notify_no_senders_t __Request;
#if    __MigTypeCheck
    if ((In0P->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) ||
        (In0P->Head.msgh_size != (mach_msg_size_t)sizeof(__Request)))
        return MIG_BAD_ARGUMENTS;
#endif

    return MACH_MSG_SUCCESS;
}
#endif
#endif
#endif



mig_internal novalue _Xmach_notify_no_senders
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP)
{

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        mach_port_mscount_t _mscnt;
        mach_msg_trailer_t trailer;
    } Request __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
    typedef __Request__mach_notify_no_senders_t __Request;
    typedef __Reply__mach_notify_no_senders_t Reply __attribute__((unused));









    Request *In0P = (Request *) InHeadP;
    Reply *OutP = (Reply *) OutHeadP;
#ifdef    __MIG_check__Request__mach_notify_no_senders_t__defined
    kern_return_t check_result;
#endif

    __DeclareRcvSimple(70, "mach_notify_no_senders")
    __BeforeRcvSimple(70, "mach_notify_no_senders")

#if    defined(__MIG_check__Request__mach_notify_no_senders_t__defined)
    check_result = __MIG_check__Request__mach_notify_no_senders_t((__Request *)In0P);
    if (check_result != MACH_MSG_SUCCESS)
        { MIG_RETURN_ERROR(OutP, check_result); }
#endif

    OutP->RetCode = _dispatch_mach_notify_no_senders(In0P->Head.msgh_request_port, In0P->_mscnt);
    __AfterRcvSimple(70, "mach_notify_no_senders")
}

#if ( __MigTypeCheck )
#if __MIG_check__Request__libdispatch_internal_protocol_subsystem__
#if !defined(__MIG_check__Request__mach_notify_send_once_t__defined)
#define __MIG_check__Request__mach_notify_send_once_t__defined

mig_internal kern_return_t __MIG_check__Request__mach_notify_send_once_t(__attribute__((__unused__)) __Request__mach_notify_send_once_t *In0P)
{

    typedef __Request__mach_notify_send_once_t __Request;
#if    __MigTypeCheck
    if ((In0P->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) ||
        (In0P->Head.msgh_size != (mach_msg_size_t)sizeof(__Request)))
        return MIG_BAD_ARGUMENTS;
#endif

    return MACH_MSG_SUCCESS;
}
#endif
#endif
#endif



mig_internal novalue _Xmach_notify_send_once
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP)
{

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        mach_msg_trailer_t trailer;
    } Request __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
    typedef __Request__mach_notify_send_once_t __Request;
    typedef __Reply__mach_notify_send_once_t Reply __attribute__((unused));









    Request *In0P = (Request *) InHeadP;
    Reply *OutP = (Reply *) OutHeadP;
#ifdef    __MIG_check__Request__mach_notify_send_once_t__defined
    kern_return_t check_result;
#endif

    __DeclareRcvSimple(71, "mach_notify_send_once")
    __BeforeRcvSimple(71, "mach_notify_send_once")

#if    defined(__MIG_check__Request__mach_notify_send_once_t__defined)
    check_result = __MIG_check__Request__mach_notify_send_once_t((__Request *)In0P);
    if (check_result != MACH_MSG_SUCCESS)
        { MIG_RETURN_ERROR(OutP, check_result); }
#endif

    OutP->RetCode = _dispatch_mach_notify_send_once(In0P->Head.msgh_request_port);
    __AfterRcvSimple(71, "mach_notify_send_once")
}

#if ( __MigTypeCheck )
#if __MIG_check__Request__libdispatch_internal_protocol_subsystem__
#if !defined(__MIG_check__Request__mach_notify_dead_name_t__defined)
#define __MIG_check__Request__mach_notify_dead_name_t__defined

mig_internal kern_return_t __MIG_check__Request__mach_notify_dead_name_t(__attribute__((__unused__)) __Request__mach_notify_dead_name_t *In0P)
{

    typedef __Request__mach_notify_dead_name_t __Request;
#if    __MigTypeCheck
    if ((In0P->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) ||
        (In0P->Head.msgh_size != (mach_msg_size_t)sizeof(__Request)))
        return MIG_BAD_ARGUMENTS;
#endif

    return MACH_MSG_SUCCESS;
}
#endif
#endif
#endif



mig_internal novalue _Xmach_notify_dead_name
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP)
{

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        NDR_record_t NDR;
        mach_port_name_t _name;
        mach_msg_trailer_t trailer;
    } Request __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
    typedef __Request__mach_notify_dead_name_t __Request;
    typedef __Reply__mach_notify_dead_name_t Reply __attribute__((unused));









    Request *In0P = (Request *) InHeadP;
    Reply *OutP = (Reply *) OutHeadP;
#ifdef    __MIG_check__Request__mach_notify_dead_name_t__defined
    kern_return_t check_result;
#endif

    __DeclareRcvSimple(72, "mach_notify_dead_name")
    __BeforeRcvSimple(72, "mach_notify_dead_name")

#if    defined(__MIG_check__Request__mach_notify_dead_name_t__defined)
    check_result = __MIG_check__Request__mach_notify_dead_name_t((__Request *)In0P);
    if (check_result != MACH_MSG_SUCCESS)
        { MIG_RETURN_ERROR(OutP, check_result); }
#endif

    OutP->RetCode = _dispatch_mach_notify_dead_name(In0P->Head.msgh_request_port, In0P->_name);
    __AfterRcvSimple(72, "mach_notify_dead_name")
}

#if ( __MigTypeCheck )
#if __MIG_check__Request__libdispatch_internal_protocol_subsystem__
#if !defined(__MIG_check__Request__wakeup_main_thread_t__defined)
#define __MIG_check__Request__wakeup_main_thread_t__defined

mig_internal kern_return_t __MIG_check__Request__wakeup_main_thread_t(__attribute__((__unused__)) __Request__wakeup_main_thread_t *In0P)
{

    typedef __Request__wakeup_main_thread_t __Request;
#if    __MigTypeCheck
    if ((In0P->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) ||
        (In0P->Head.msgh_size != (mach_msg_size_t)sizeof(__Request)))
        return MIG_BAD_ARGUMENTS;
#endif

    return MACH_MSG_SUCCESS;
}
#endif
#endif
#endif



mig_internal novalue _Xwakeup_main_thread
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP)
{

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        mach_msg_trailer_t trailer;
    } Request __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
    typedef __Request__wakeup_main_thread_t __Request;
    typedef __Reply__wakeup_main_thread_t Reply __attribute__((unused));









    Request *In0P = (Request *) InHeadP;
    Reply *OutP = (Reply *) OutHeadP;
#ifdef    __MIG_check__Request__wakeup_main_thread_t__defined
    kern_return_t check_result;
#endif

    __DeclareRcvSimple(78, "wakeup_main_thread")
    __BeforeRcvSimple(78, "wakeup_main_thread")

#if    defined(__MIG_check__Request__wakeup_main_thread_t__defined)
    check_result = __MIG_check__Request__wakeup_main_thread_t((__Request *)In0P);
    if (check_result != MACH_MSG_SUCCESS)
        { MIG_RETURN_ERROR(OutP, check_result); }
#endif

    OutP->RetCode = _dispatch_wakeup_main_thread(In0P->Head.msgh_request_port);
    __AfterRcvSimple(78, "wakeup_main_thread")
}

#if ( __MigTypeCheck )
#if __MIG_check__Request__libdispatch_internal_protocol_subsystem__
#if !defined(__MIG_check__Request__consume_send_once_right_t__defined)
#define __MIG_check__Request__consume_send_once_right_t__defined

mig_internal kern_return_t __MIG_check__Request__consume_send_once_right_t(__attribute__((__unused__)) __Request__consume_send_once_right_t *In0P)
{

    typedef __Request__consume_send_once_right_t __Request;
#if    __MigTypeCheck
    if ((In0P->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) ||
        (In0P->Head.msgh_size != (mach_msg_size_t)sizeof(__Request)))
        return MIG_BAD_ARGUMENTS;
#endif

    return MACH_MSG_SUCCESS;
}
#endif
#endif
#endif



mig_internal novalue _Xconsume_send_once_right
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP)
{

#ifdef  __MigPackStructs
#pragma pack(push, 4)
#endif
    typedef struct {
        mach_msg_header_t Head;
        mach_msg_trailer_t trailer;
    } Request __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack(pop)
#endif
    typedef __Request__consume_send_once_right_t __Request;
    typedef __Reply__consume_send_once_right_t Reply __attribute__((unused));









    Request *In0P = (Request *) InHeadP;
    Reply *OutP = (Reply *) OutHeadP;
#ifdef    __MIG_check__Request__consume_send_once_right_t__defined
    kern_return_t check_result;
#endif

    __DeclareRcvSimple(79, "consume_send_once_right")
    __BeforeRcvSimple(79, "consume_send_once_right")

#if    defined(__MIG_check__Request__consume_send_once_right_t__defined)
    check_result = __MIG_check__Request__consume_send_once_right_t((__Request *)In0P);
    if (check_result != MACH_MSG_SUCCESS)
        { MIG_RETURN_ERROR(OutP, check_result); }
#endif

    OutP->RetCode = _dispatch_consume_send_once_right(In0P->Head.msgh_request_port);
    __AfterRcvSimple(79, "consume_send_once_right")
}




const struct _dispatch_libdispatch_internal_protocol_subsystem _dispatch_libdispatch_internal_protocol_subsystem = {
    libdispatch_internal_protocol_server_routine,
    64,
    80,
    (mach_msg_size_t)sizeof(union __ReplyUnion___dispatch_libdispatch_internal_protocol_subsystem),
    (vm_address_t)0,
    {
        {0, 0, 0, 0, 0, 0},
          { (mig_impl_routine_t) 0,
          (mig_stub_routine_t) _Xmach_notify_port_deleted, 2, 0, (routine_arg_descriptor_t)0, (mach_msg_size_t)sizeof(__Reply__mach_notify_port_deleted_t)},
          { (mig_impl_routine_t) 0,
          (mig_stub_routine_t) _Xmach_notify_send_possible, 2, 0, (routine_arg_descriptor_t)0, (mach_msg_size_t)sizeof(__Reply__mach_notify_send_possible_t)},
        {0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0},
          { (mig_impl_routine_t) 0,
          (mig_stub_routine_t) _Xmach_notify_port_destroyed, 2, 0, (routine_arg_descriptor_t)0, (mach_msg_size_t)sizeof(__Reply__mach_notify_port_destroyed_t)},
          { (mig_impl_routine_t) 0,
          (mig_stub_routine_t) _Xmach_notify_no_senders, 2, 0, (routine_arg_descriptor_t)0, (mach_msg_size_t)sizeof(__Reply__mach_notify_no_senders_t)},
          { (mig_impl_routine_t) 0,
          (mig_stub_routine_t) _Xmach_notify_send_once, 1, 0, (routine_arg_descriptor_t)0, (mach_msg_size_t)sizeof(__Reply__mach_notify_send_once_t)},
          { (mig_impl_routine_t) 0,
          (mig_stub_routine_t) _Xmach_notify_dead_name, 2, 0, (routine_arg_descriptor_t)0, (mach_msg_size_t)sizeof(__Reply__mach_notify_dead_name_t)},
        {0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0},
          { (mig_impl_routine_t) 0,
          (mig_stub_routine_t) _Xwakeup_main_thread, 1, 0, (routine_arg_descriptor_t)0, (mach_msg_size_t)sizeof(__Reply__wakeup_main_thread_t)},
          { (mig_impl_routine_t) 0,
          (mig_stub_routine_t) _Xconsume_send_once_right, 1, 0, (routine_arg_descriptor_t)0, (mach_msg_size_t)sizeof(__Reply__consume_send_once_right_t)},
    }
};

mig_external boolean_t libdispatch_internal_protocol_server
    (mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP)
{








    mig_routine_t routine;

    OutHeadP->msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REPLY(InHeadP->msgh_bits), 0);
    OutHeadP->msgh_remote_port = InHeadP->msgh_reply_port;

    OutHeadP->msgh_size = (mach_msg_size_t)sizeof(mig_reply_error_t);
    OutHeadP->msgh_local_port = MACH_PORT_NULL;
    OutHeadP->msgh_id = InHeadP->msgh_id + 100;
    OutHeadP->msgh_reserved = 0;

    if ((InHeadP->msgh_id > 79) || (InHeadP->msgh_id < 64) ||
        ((routine = _dispatch_libdispatch_internal_protocol_subsystem.routine[InHeadP->msgh_id - 64].stub_routine) == 0)) {
        ((mig_reply_error_t *)OutHeadP)->NDR = NDR_record;
        ((mig_reply_error_t *)OutHeadP)->RetCode = MIG_BAD_ID;
        return FALSE;
    }
    (*routine) (InHeadP, OutHeadP);
    return TRUE;
}

mig_external mig_routine_t libdispatch_internal_protocol_server_routine
    (mach_msg_header_t *InHeadP)
{
    int msgh_id;

    msgh_id = InHeadP->msgh_id - 64;

    if ((msgh_id > 15) || (msgh_id < 0))
        return 0;

    return _dispatch_libdispatch_internal_protocol_subsystem.routine[msgh_id].stub_routine;
}
