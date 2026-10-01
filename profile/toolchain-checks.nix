# Exercise the installed bundle, rather than an independently assembled shell.
{
  pkgs,
  bundle,
  versions,
}:
let
  check =
    name: script:
    pkgs.runCommand name { } ''
      export PATH=${bundle}/bin:$PATH
      export HOME=$TMPDIR/home
      mkdir -p "$HOME"
      ${script}
      touch $out
    '';
in
{
  c-cpp = check "check-profile-c-cpp" ''
    test "$(readlink -f ${bundle}/bin/cc)" = "$(readlink -f ${pkgs.gcc_multi}/bin/cc)"
    clang --version | ${pkgs.gnugrep}/bin/grep -F '${versions.c-cpp-toolchain.clang}'
    cat > hello.c <<'C'
    int main(void) { return 0; }
    C
    gcc hello.c -o hello-gcc
    ./hello-gcc
    gcc -m32 hello.c -o hello32
    ${pkgs.file}/bin/file hello32 | ${pkgs.gnugrep}/bin/grep -F 'ELF 32-bit'
    ./hello32
    clang hello.c -o hello-clang
    ./hello-clang
    clang -S -emit-llvm hello.c -o hello.ll
    llvm-as hello.ll -o hello.bc
    opt -passes=verify hello.bc -o verified.bc
    printf '%s\n' '#include <iostream>' 'int main() { std::cout << "ok"; }' > hello.cpp
    g++ hello.cpp -o hello-cpp
    test "$(./hello-cpp)" = ok
    clangd --version
    clang-format --version
  '';

  java = check "check-profile-java" ''
    cat > Hello.java <<'JAVA'
    public class Hello {
      public static void main(String[] args) {
        if (Runtime.version().feature() != 21) throw new AssertionError();
        System.out.print("profile-java-ok");
      }
    }
    JAVA
    javac Hello.java
    test "$(java Hello)" = profile-java-ok
  '';

  nodejs = check "check-profile-nodejs" ''
    node -e 'if (!process.version.startsWith("v22.")) process.exit(1)'
    npm --version
  '';

  python = check "check-profile-python" ''
    uv --version
    ruff --version
    printf '%s\n' 'print("profile-python-ok")' > hello.py
    ruff check hello.py
    ruff format --check hello.py
    uv venv --python ${pkgs.python3}/bin/python --no-python-downloads env
    test "$(env/bin/python hello.py)" = profile-python-ok
  '';

  openmpi = check "check-profile-openmpi" ''
    cat > hello-mpi.c <<'C'
    #include <mpi.h>
    int main(int argc, char **argv) {
      int size, rank, sum;
      MPI_Init(&argc, &argv);
      MPI_Comm_size(MPI_COMM_WORLD, &size);
      MPI_Comm_rank(MPI_COMM_WORLD, &rank);
      MPI_Allreduce(&rank, &sum, 1, MPI_INT, MPI_SUM, MPI_COMM_WORLD);
      MPI_Finalize();
      return size == 2 && sum == 1 ? 0 : 1;
    }
    C
    mpicc hello-mpi.c -o hello-mpi
    # Nix's network sandbox has only loopback, which TCP BTL excludes by default.
    # https://docs.open-mpi.org/en/v5.0.2/tuning-apps/networking/tcp.html
    timeout 30 mpirun --oversubscribe -n 2 --mca pml ob1 --mca btl self,tcp \
      --mca btl_tcp_if_include lo ./hello-mpi
  '';

  ros2 = check "check-profile-ros2" ''
    ros2 pkg list > packages.txt
    ${pkgs.gnugrep}/bin/grep -Fx ament_cmake packages.txt
    ${pkgs.gnugrep}/bin/grep -Fx rclcpp packages.txt
    ros2 interface show std_msgs/msg/String
    mkdir -p src/profile_ros_smoke
    cat > src/profile_ros_smoke/package.xml <<'XML'
    <package format="3">
      <name>profile_ros_smoke</name><version>0.1.0</version>
      <description>Profile colcon build fixture</description>
      <maintainer email="fixture@example.invalid">Fixture</maintainer>
      <license>MIT</license><buildtool_depend>cmake</buildtool_depend>
      <export><build_type>cmake</build_type></export>
    </package>
    XML
    cat > src/profile_ros_smoke/CMakeLists.txt <<'CMAKE'
    cmake_minimum_required(VERSION 3.16)
    project(profile_ros_smoke C)
    add_executable(profile_ros_smoke main.c)
    install(TARGETS profile_ros_smoke DESTINATION bin)
    CMAKE
    printf '%s\n' 'int main(void) { return 0; }' > src/profile_ros_smoke/main.c
    colcon list --base-paths src
    colcon build --base-paths src --event-handlers console_direct+
    install/profile_ros_smoke/bin/profile_ros_smoke
  '';

  document-and-build-tools = check "check-profile-document-build-tools" ''
    printf '%s\n' '= Profile test' 'Version-locked document compilation.' > document.typ
    typst compile document.typ document.pdf
    test -s document.pdf
    printf '%s\n' 'default:' '    printf profile-just-ok' > justfile
    just default > just-output.txt
    test "$(cat just-output.txt)" = profile-just-ok
    test -s ${bundle}/share/zsh/site-functions/_just
    ${pkgs.zsh}/bin/zsh -f -c '
      fpath=(${bundle}/share/zsh/site-functions $fpath)
      autoload -Uz _just
      autoload +X _just
      (( $+functions[_just] ))
    '
  '';
}
