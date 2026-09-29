# --- openmpi ---
# MPI implementation: out provides mpirun / mpiexec, while the compiler
# wrappers (mpicc / mpicxx / mpifort) and mpi.h live in the dev output, so both
# outputs must be installed for `mpicc` to be on PATH.
{ pkgs, ... }:
{
  home.packages = [
    pkgs.openmpi
    pkgs.openmpi.dev
  ];
}
