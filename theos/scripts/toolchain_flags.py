ARM32_ARCHS = ('armv6', 'armv7')
ARM32_CODEGEN_FLAGS = ['-mllvm', '-post-RA-scheduler=false']


def codegen_flags(arch):
    return list(ARM32_CODEGEN_FLAGS) if arch in ARM32_ARCHS else []
