{ pkgs }:
{
  # Compiler wrappers and mpi.h are in dev, mpirun/mpiexec are in out.
  packages = [
    pkgs.openmpi
    pkgs.openmpi.dev
  ];
  versions.openmpi = pkgs.openmpi.version;
}
