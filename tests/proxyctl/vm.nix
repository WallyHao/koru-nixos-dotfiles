# Offline integration coverage: real sudo, credentials, TUN and service recovery.
{ pkgs }:
let
  provider = pkgs.writeText "proxy-test-provider.yaml" ''
    proxies:
      - {name: Hong Kong old, type: direct}
  '';
  fixtureServer = pkgs.writeText "proxy-test-server.py" ''
    import http.server
    import time

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_HEAD(self):
            time.sleep(0.03)
            self.send_response(204)
            self.end_headers()

        def do_GET(self):
            time.sleep(0.03)
            if self.path.startswith("/subscription"):
                name = "Hong Kong new" if "missing" in self.path else "Hong Kong old"
                body = f"proxies:\n  - {{name: {name}, type: direct}}\n".encode()
                self.send_response(200)
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_response(204)
                self.end_headers()

    http.server.ThreadingHTTPServer(("127.0.0.1", 8000), Handler).serve_forever()
  '';
in
pkgs.testers.runNixOSTest {
  name = "proxyctl-lifecycle";
  nodes.machine = {
    imports = [ ../../system/mihomo.nix ];
    _module.args = {
      username = "proxy-test";
      theme = import ../../system/theme.nix;
    };
    users.users.proxy-test.isNormalUser = true;
    koru.proxy.latencyUrl = "http://127.0.0.1:8000/delay";
    # Refreshing an active proxy normally prompts for stop authorization. This
    # isolated VM grants that exact operation to exercise unattended recovery.
    security.sudo.extraRules = [
      {
        users = [ "proxy-test" ];
        commands = [
          {
            command = "${pkgs.systemd}/bin/systemctl stop mihomo";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl stop mihomo";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
    virtualisation.memorySize = 1024;
    systemd.services.proxy-fixture = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.python3}/bin/python ${fixtureServer}";
    };
  };

  testScript = ''
    import json

    start_all()
    machine.wait_for_unit("proxy-fixture.service")
    machine.wait_for_open_port(8000)
    directory = "/home/proxy-test/.config/mihomo"
    user_command = "runuser -u proxy-test -- proxyctl "
    machine.succeed(f"install -d -o proxy-test -g users -m 0700 {directory}")
    machine.succeed(f"install -o proxy-test -g users -m 0600 ${provider} {directory}/provider.yaml")
    machine.succeed(f"echo '[{{\"name\":\"Hong Kong old\",\"latency_ms\":42}}]' > {directory}/nodes.json")
    machine.succeed(f"chown proxy-test:users {directory}/nodes.json")

    with subtest("legacy migration and passwordless start"):
        machine.succeed(user_command + "start --node 'Hong Kong old'")
        machine.wait_for_unit("mihomo.service")
        machine.succeed(f"test -L {directory}/cache/current && test -L {directory}/provider.yaml")
        state = json.loads(machine.succeed(user_command + "status --json"))
        assert state["service"] == "active" and state["node"] == "Hong Kong old"
        assert state["tun"] == "active", state

    def subscription(path):
        machine.succeed(f"echo http://127.0.0.1:8000/{path} > {directory}/subscription-url")
        machine.succeed(f"chown proxy-test:users {directory}/subscription-url")

    # All subscription and latency requests stay on the fixture's loopback.
    refresh = user_command + "refresh --restore"

    with subtest("refresh publishes credentials and restores the active node"):
        subscription("subscription")
        before = machine.succeed(f"readlink {directory}/cache/current").strip()
        machine.succeed(refresh)
        after = machine.succeed(f"readlink {directory}/cache/current").strip()
        assert before != after
        machine.wait_for_unit("mihomo.service")
        assert json.loads(machine.succeed(user_command + "status --json"))["node"] == "Hong Kong old"

    with subtest("root refresh keeps the cache readable by its owner"):
        machine.succeed("proxyctl refresh --restore")
        after = machine.succeed(f"readlink {directory}/cache/current").strip()
        assert len(json.loads(machine.succeed(user_command + "nodes --json"))) == 1

    with subtest("unusable replacement preserves the old cache and service"):
        subscription("subscription-missing")
        machine.fail(refresh)
        assert machine.succeed(f"readlink {directory}/cache/current").strip() == after
        machine.wait_for_unit("mihomo.service")
        assert json.loads(machine.succeed(user_command + "status --json"))["node"] == "Hong Kong old"

    with subtest("shutdown removes the TUN"):
        machine.succeed("proxyctl shutdown")
        machine.wait_until_fails("systemctl is-active --quiet mihomo")
        machine.wait_until_fails("ip link show mihomo")
  '';
}
