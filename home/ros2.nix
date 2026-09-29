# --- ros2 ---
# ROS 2 Humble. Humble is not packaged in nixpkgs anymore, so it comes from the
# community nix-ros-overlay: flake.nix builds a dedicated `rosPkgs` instance
# with that overlay applied, keeping its package overrides away from the system.
#
# `buildEnv` merges the selected ROS packages into one store path; installing
# that single derivation puts every ROS bin (ros2, ros2 run, ros2 launch, ...)
# on PATH, so no `setup.bash` sourcing is required. colcon is the build tool.
{ rosPkgs, ... }:
let
  ros = rosPkgs.rosPackages.humble;
in
{
  home.packages = [
    rosPkgs.colcon
    (ros.buildEnv {
      name = "ros2-humble-env";
      paths = with ros; [
        ros-base
        ament-cmake-core
        python-cmake-module
      ];
    })
  ];
}
