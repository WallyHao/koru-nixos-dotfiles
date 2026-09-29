# --- cpp ---
# C/C++ development environment for CS323: compilers, build systems, debugger
# and the clangd language server used by the editor (nvim).
#
# LLVM/Clang are pinned to 19 to match the course reference environment
# (Debian 13: clang-19 / llvm-19); LLVM IR is not compatible across major
# versions, so the labs must build against 19. GNU gcc stays the default host
# compiler. flex/bison are in the course's apt list.
#
# CS315's buffer-overflow lab compiles 32-bit binaries with -m32, which the
# plain gcc cannot link (no i686 libc/libgcc). gcc_multi is gcc plus multilib,
# so it replaces plain gcc rather than sitting next to it.
{ pkgs, ... }:
let
  llvm = pkgs.llvmPackages_19;
in
{
  home.packages =
    with pkgs;
    [
      # gcc and clang both ship bin/cc and bin/c++ wrappers; buildEnv rejects
      # that as a collision. hiPrio lets gcc own cc/c++ (the usual Linux
      # default) while clang 19 stays available as clang / clang++.
      (pkgs.lib.hiPrio gcc_multi) # GNU C/C++ compiler (32/64-bit), owns cc/c++
      gnumake # make
      cmake
      ninja
      pkg-config
      ccache # compiler cache
      gdb # debugger
      valgrind # memory checker
      mold # fast linker
      flex # lexer generator
      bison # parser generator
    ]
    ++ [
      llvm.clang # clang / clang++ 19
      llvm.clang-tools # clangd, clang-format, clang-tidy 19
      llvm.llvm # llvm-* tools (opt, llc, llvm-as, ...)
      llvm.lld # LLVM linker
    ];
}
