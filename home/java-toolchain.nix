# --- jdk ---
# Java development kit (javac, java, jshell, ...).
# Pinned to 21 to match the CS323 reference environment (Debian openjdk-21-jdk);
# the course's ANTLR projects are built and run with JDK 21.
{ pkgs, ... }:
{
  home.packages = [ pkgs.jdk21 ];
}
