# Keep ROS on its overlay's own nixpkgs revision and preserve its buildEnv.
{ rosPkgs }:
let
  ros = rosPkgs.rosPackages.humble;
in
{
  packages = [
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
  versions = {
    distribution = "humble";
    ros-base = ros.ros-base.version;
    colcon = rosPkgs.colcon.version;
  };
}
