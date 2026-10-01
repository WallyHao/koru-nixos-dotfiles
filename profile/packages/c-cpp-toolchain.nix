# LLVM 19 for CS323 and GCC multilib for CS315's 32-bit labs.
{ pkgs }:
let
  llvm = pkgs.llvmPackages_19;
in
assert pkgs.lib.assertMsg (
  pkgs.lib.versions.major llvm.clang.version == "19"
) "The C/C++ profile requires LLVM/Clang 19";
{
  packages = with pkgs; [
    # Both GCC and Clang provide cc/c++; retain GCC as the default.
    (lib.hiPrio gcc_multi)
    gnumake
    cmake
    ninja
    pkg-config
    ccache
    gdb
    valgrind
    mold
    flex
    bison
    llvm.clang
    llvm.clang-tools
    llvm.llvm
    llvm.lld
  ];
  versions = {
    gcc = pkgs.gcc_multi.version;
    clang = llvm.clang.version;
    llvm = llvm.llvm.version;
    cmake = pkgs.cmake.version;
    ninja = pkgs.ninja.version;
    gdb = pkgs.gdb.version;
  };
}
