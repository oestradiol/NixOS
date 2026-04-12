{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.security.sandboxedBrowsers;

  # Browser sandboxing: UID isolation (100000:100000), process namespace, minimal FS access
  #
  # ISOLATION PROVIDED:
  # - UID namespace: browser runs as UID 100000 (unmapped on host)
  # - IPC/PID/UTS namespaces for process isolation
  # - Capability dropping (--cap-drop ALL)
  # - Ephemeral tmpfs home (no persistent browser state)
  # - Optional D-Bus filtering via xdg-dbus-proxy (when dbusFilter enabled)
  #
  # ISOLATION LIMITATIONS (read carefully):
  # - Network namespace is NOT isolated (--unshare-net not used) — browser has full host network
  # - Selective /run binds: XDG runtime, D-Bus system socket (not full /run)
  # - GPU passthrough (--dev-bind /dev/dri) — GPU drivers are known escape vectors via DMA
  # - D-Bus filtering is OPTIONAL (disabled by default) — enable via myOS.security.sandboxedBrowsers.dbusFilter
  #   When disabled: D-Bus system socket still exposed — potential breakout path
  # - Even with D-Bus filtering, these wrappers provide DAMAGE REDUCTION, not strong isolation
  #
  # COMPATIBILITY TRADE-OFFS (daily profile):
  # - Full /var access for system state compatibility (Flatpak, systemd user sessions)
  # - /etc read-only for system configuration
  # - /dev/dri for GPU rendering (no software rendering fallback)
  #
  # SECURITY REALITY CHECK:
  # These wrappers provide DAMAGE REDUCTION for accidental misclicks and basic containment.
  # They do NOT provide "trustworthy hostile-content isolation" against motivated attackers.
  # For malicious PDFs, suspicious executables, or untrusted web content: use VM isolation.
  #
  # For maximum isolation: enable myOS.security.vmIsolation and run browsers in a VM.
  #
  # References:
  # - Tor Browser D-Bus namespace: https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/44050
  # - xdg-dbus-proxy man page: https://man.archlinux.org/man/xdg-dbus-proxy.1.en
  # - bubblewrap D-Bus security: https://github.com/containers/bubblewrap/blob/main/README.md
  mkSandboxedBrowser = { 
    name, 
    package, 
    binaryName ? name, 
    # CONSERVATIVE DEFAULT: no extra binds (add only what's needed per-app)
    extraBinds ? [], 
    # CONSERVATIVE DEFAULT: no D-Bus own-name (null = no --own policy)
    # Set to "org.mozilla.firefox.*" or browser-specific namespace
    dbusOwnName ? null,
    # CONSERVATIVE DEFAULT: false (don't add user.js - only Firefox needs this)
    injectUserJS ? false,
  }: 
    let
      dbusOwnArg = if dbusOwnName != null then "--own=${dbusOwnName}" else "";
    in
    pkgs.writeShellScriptBin "safe-${name}" ''
      set -eu
      
      RUNTIME="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/safe-${name}"
      PROFILE="$RUNTIME/profile"
      CACHE="$RUNTIME/cache"
      mkdir -p "$PROFILE" "$CACHE"
      
      # Inject hardened user.js if requested (Firefox only)
      ${if injectUserJS then ''
      if [[ ! -f "$PROFILE/user.js" ]]; then
        cp ${hardenedUserJS} "$PROFILE/user.js"
      fi
      '' else "# No user.js injection for this browser\n      :"}
      
      # GPU and display sockets
      DISPLAY_SOCK="''${WAYLAND_DISPLAY:-$DISPLAY}"
      [[ -n "''${WAYLAND_DISPLAY:-}" ]] && WAYLAND_SOCK="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
      [[ -S "$XDG_RUNTIME_DIR/pipewire-0" ]] && PIPEWIRE_SOCK="$XDG_RUNTIME_DIR/pipewire-0"
      [[ -d /dev/dri ]] && GPU_DEV="/dev/dri"
      
      # D-Bus filtering setup (when enabled)
      DBUS_PROXY_SOCK=""
      DBUS_SYSTEM_PROXY_SOCK=""
      ${if cfg.dbusFilter then ''
      DBUS_PROXY_SOCK="$RUNTIME/dbus-proxy.sock"
      DBUS_SYSTEM_PROXY_SOCK="$RUNTIME/dbus-system-proxy.sock"
      
      # Start xdg-dbus-proxy for filtered SESSION bus access
      # Allows: own name, talk to portal, a11y, MPRIS, receive portal signals
      # Blocks: unrestricted session bus access
      ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
        "$DBUS_SESSION_BUS_ADDRESS" \
        "$DBUS_PROXY_SOCK" \
        --filter \
        ${dbusOwnArg} \
        --talk=org.freedesktop.portal.* \
        --talk=org.a11y.Bus \
        --talk=org.mpris.MediaPlayer2.* \
        --broadcast=org.freedesktop.portal.*=@/org/freedesktop/portal/* &
      DBUS_PID=$!
      
      # Start xdg-dbus-proxy for filtered SYSTEM bus access
      # Allows: limited system services (NetworkManager for captive portal, systemd for logind)
      # Blocks: unrestricted system bus access (systemd exploitation risk)
      ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
        "unix:path=/run/dbus/system_bus_socket" \
        "$DBUS_SYSTEM_PROXY_SOCK" \
        --filter \
        --talk=org.freedesktop.NetworkManager \
        --talk=org.freedesktop.login1 &
      DBUS_SYSTEM_PID=$!
      
      cleanup() { 
        kill $DBUS_PID 2>/dev/null || true
        kill $DBUS_SYSTEM_PID 2>/dev/null || true
      }
      trap cleanup EXIT
      '' else "# D-Bus filtering disabled — direct /run access allows full D-Bus access (breakage risk)\n      :"}
      
      exec ${pkgs.bubblewrap}/bin/bwrap \
        --new-session \
        --die-with-parent \
        --unshare-user \
        --uid 100000 --gid 100000 \
        --unshare-ipc \
        --unshare-pid \
        --unshare-uts \
        --proc /proc \
        --dev /dev \
        --ro-bind /nix /nix \
        --ro-bind /etc /etc \
        --ro-bind /usr /usr \
        --ro-bind /bin /bin \
        --ro-bind /sbin /sbin \
        --ro-bind /lib /lib \
        --ro-bind /lib64 /lib64 \
        # Selective /run binds (not full /run) — daily compatibility profile
        --ro-bind /run/user/$(id -u) /run/user/$(id -u) \
        ${if cfg.dbusFilter then "# D-Bus filtered via proxy — session + system bus\n        --ro-bind \"$DBUS_PROXY_SOCK\" \"\''${XDG_RUNTIME_DIR}/bus\" \\ 
        --ro-bind \"$DBUS_SYSTEM_PROXY_SOCK\" \"\''${XDG_RUNTIME_DIR}/system-bus-proxy.sock\"" else "--ro-bind /run/dbus/system_bus_socket /run/dbus/system_bus_socket"} \\
        --ro-bind /var /var \
        --bind "$RUNTIME" "$HOME" \
        --tmpfs /tmp \
        ''${WAYLAND_SOCK:+--ro-bind "$WAYLAND_SOCK" "$WAYLAND_SOCK"} \
        ''${PIPEWIRE_SOCK:+--ro-bind "$PIPEWIRE_SOCK" "$PIPEWIRE_SOCK"} \
        ''${GPU_DEV:+--dev-bind /dev/dri /dev/dri} \
        --dev-bind /dev/null /dev/null \
        --dev-bind /dev/zero /dev/zero \
        --dev-bind /dev/random /dev/random \
        --dev-bind /dev/urandom /dev/urandom \
        --dev-bind /dev/tty /dev/tty \
        ${lib.concatMapStrings (b: "--bind ${b.from} ${b.to} ") extraBinds} \
        --setenv HOME "$HOME" \
        --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR" \
        --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" \
        --setenv DISPLAY "$DISPLAY" \
        ${if cfg.dbusFilter then "--setenv DBUS_SESSION_BUS_ADDRESS \"unix:path=\''${XDG_RUNTIME_DIR}/bus\" --setenv DBUS_SYSTEM_BUS_ADDRESS \"unix:path=\''${XDG_RUNTIME_DIR}/system-bus-proxy.sock\"" else ""} \\
        --cap-drop ALL \
        ${package}/bin/${binaryName} --no-remote --profile "$PROFILE" "$@"
    '';
  
  # Hardened user.js for Firefox - based on arkenfox research
  # Comprehensive privacy/security hardening with minimal breakage
  hardenedUserJS = pkgs.writeText "user.js" ''
    // Firefox hardening preferences - grounded in arkenfox research
    // [SECTION 0000]: UI
    user_pref("browser.aboutConfig.showWarning", false);
    
    // [SECTION 0100]: STARTUP
    user_pref("browser.startup.page", 0); // Blank page
    user_pref("browser.startup.homepage", "about:blank");
    user_pref("browser.newtabpage.enabled", false);
    user_pref("browser.newtabpage.activity-stream.showSponsored", false);
    user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
    user_pref("browser.newtabpage.activity-stream.default.sites", "");
    user_pref("browser.sessionstore.resume_from_crash", false);
    
    // [SECTION 0200]: GEOLOCATION
    user_pref("geo.enabled", false);
    user_pref("geo.provider.ms-windows-location", false);
    user_pref("geo.provider.use_corelocation", false);
    user_pref("geo.provider.use_gpsd", false);
    user_pref("geo.provider.use_geoclue", false);
    
    // [SECTION 0300]: QUIETER FOX (Telemetry/Studies)
    user_pref("toolkit.telemetry.enabled", false);
    user_pref("toolkit.telemetry.unified", false);
    user_pref("toolkit.telemetry.archive.enabled", false);
    user_pref("datareporting.healthreport.uploadEnabled", false);
    user_pref("datareporting.policy.dataSubmissionEnabled", false);
    user_pref("app.shield.optoutstudies.enabled", false);
    user_pref("app.normandy.enabled", false); // Shield/Normandy system
    user_pref("app.normandy.api_url", "");
    user_pref("browser.discovery.enabled", false);
    user_pref("browser.tabs.firefox-view", false);
    user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
    user_pref("browser.newtabpage.activity-stream.telemetry", false);
    user_pref("browser.ping-centre.telemetry", false);
    user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);
    user_pref("breakpad.reportURL", "");
    user_pref("browser.tabs.crashReporting.sendReport", false);
    
    // [SECTION 0400]: SAFE BROWSING
    user_pref("browser.safebrowsing.downloads.remote.enabled", false); // Local DB only
    user_pref("browser.safebrowsing.phishing.enabled", true);
    user_pref("browser.safebrowsing.malware.enabled", true);
    
    // [SECTION 0600]: BLOCK IMPLICIT OUTBOUND
    user_pref("network.prefetch-next", false);
    user_pref("network.dns.disablePrefetch", true);
    user_pref("network.dns.disablePrefetchFromHTTPS", true);
    user_pref("network.predictor.enabled", false);
    user_pref("network.http.speculative-parallel-limit", 0);
    user_pref("browser.places.speculativeConnect.enabled", false);
    user_pref("browser.urlbar.speculativeConnect.enabled", false);
    
    // [SECTION 0700]: DNS / PROXY / SOCKS
    user_pref("network.proxy.socks_remote_dns", true);
    user_pref("network.file.disable_unc_paths", true);
    user_pref("network.gio.supported-protocols", "");
    // PARANOID PROFILE: Use Mullvad VPN server DNS (no DoH)
    // Mullvad's VPN server DNS provides same filtering (all.dns) without double-hop latency.
    // This follows vendor guidance and ensures DNS always goes through VPN tunnel.
    // DoH is disabled (TRR mode 0) to prevent any external DoH leaks.
    //
    // NOTE: When VPN is connected, Mullvad's server DNS is used automatically.
    // When VPN is disconnected, no DNS leaks due to nftables killswitch.
    user_pref("network.trr.mode", 0); // DoH disabled - use VPN server DNS only
    
    // [SECTION 0800]: LOCATION BAR / SEARCH
    user_pref("browser.search.suggest.enabled", false);
    user_pref("browser.urlbar.suggest.searches", false);
    
    // [SECTION 1200]: HTTPS / SSL / TLS / CERTS
    user_pref("dom.security.https_only_mode", true);
    user_pref("dom.security.https_only_mode_ever_enabled", true);
    user_pref("dom.security.https_only_mode_send_http_background_request", false);
    user_pref("security.ssl.require_safe_negotiation", true);
    user_pref("security.ssl.treat_unsafe_negotiation_as_broken", true);
    user_pref("security.tls.enable_0rtt_data", false); // Disable 0-RTT (not forward secret)
    user_pref("security.OCSP.enabled", 1);
    user_pref("security.OCSP.require", true); // Hard-fail on OCSP errors
    user_pref("security.cert_pinning.enforcement_level", 2); // Strict HPKP
    user_pref("security.remote_settings.crlite_filters.enabled", true);
    user_pref("security.pki.crlite_mode", 2); // Enforce CRLite
    user_pref("browser.xul.error_pages.expert_bad_cert", true);
    user_pref("browser.ssl_override_behavior", 1);
    
    // [SECTION 1600]: REFERERS
    user_pref("network.http.referer.XOriginTrimmingPolicy", 2); // Scheme+host+port only
    
    // [SECTION 1700]: CONTAINERS
    user_pref("privacy.userContext.enabled", true); // Enable container tabs
    user_pref("privacy.userContext.ui.enabled", true);
    
    // [SECTION 2000]: WEBRTC / MEDIA
    user_pref("media.peerconnection.enabled", false); // WebRTC disabled (leaks IP)
    user_pref("media.peerconnection.ice.proxy_only_if_behind_proxy", true);
    user_pref("media.peerconnection.ice.default_address_only", true);
    
    // [SECTION 2400]: DOM - FPI enabled for maximum isolation
    // FPI (First-Party Isolate) provides stronger cookie isolation than ETP Strict + TCP alone.
    // This is an intentional hardening choice for paranoid profile - security over alignment.
    user_pref("privacy.firstparty.isolate", true);
    user_pref("privacy.firstparty.isolate.restrict_opener_access", true);
    
    // [SECTION 2600]: MISC
    user_pref("network.cookie.cookieBehavior", 5); // dFPI + reject cross-site
    user_pref("browser.contentblocking.category", "strict");
    user_pref("extensions.pocket.enabled", false);
    user_pref("identity.fxaccounts.enabled", false); // Firefox Sync
    user_pref("extensions.enabledScopes", 5); // Limit extension sources
    user_pref("extensions.postDownloadThirdPartyPrompt", false);
    user_pref("browser.download.useDownloadDir", false); // Ask where to save
    user_pref("browser.download.always_ask_before_handling_new_types", true);
    
    // [SECTION 2700]: ETP
    user_pref("privacy.trackingprotection.enabled", true);
    user_pref("privacy.trackingprotection.socialtracking.enabled", true);
    user_pref("privacy.partition.network_state.ocsp_cache", true);
    user_pref("privacy.partition.serviceWorkers", true);
    
    // [SECTION 2800]: SHUTDOWN & SANITIZING
    user_pref("privacy.sanitize.sanitizeOnShutdown", true);
    user_pref("privacy.clearOnShutdown_v2.cache", true);
    user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", true);
    user_pref("privacy.clearOnShutdown_v2.formdata", true);
    user_pref("privacy.sanitize.timeSpan", 0); // Clear everything
    user_pref("privacy.clearHistory.cache", true);
    user_pref("privacy.clearHistory.formdata", true);
    user_pref("privacy.clearSiteData.cache", true);
    user_pref("privacy.clearSiteData.formdata", true);
    
    // [SECTION 4500]: RFP (Resist Fingerprinting)
    user_pref("privacy.resistFingerprinting", true);
    user_pref("privacy.resistFingerprinting.letterboxing", true);
    
    // [SECTION 8500]: CAPTIVE PORTAL / CONNECTIVITY
    user_pref("captivedetect.canonicalURL", "");
    user_pref("network.captive-portal-service.enabled", false);
    user_pref("network.connectivity-service.enabled", false);
  '';
  
  # Firefox: hardened with user.js injection (only difference from generic)
  safeFirefox = mkSandboxedBrowser {
    name = "firefox";
    package = pkgs.firefox;
    binaryName = "firefox";
    dbusOwnName = "org.mozilla.firefox.*";
    injectUserJS = true;  # Firefox-specific: inject hardened user.js
  };
  
  # Tor Browser: minimal differences from Firefox
  # D-Bus namespace: uses org.mozilla (not org.torproject yet)
  # GitLab issue: https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/44050
  # MONITOR: Check if Tor Browser changes D-Bus namespace in future releases
  safeTor = mkSandboxedBrowser {
    name = "tor-browser";
    package = pkgs.tor-browser;
    binaryName = "tor-browser";
    dbusOwnName = "org.mozilla.firefox.*";  # Same as Firefox until GitLab issue resolved
  };
  
  # Mullvad Browser: minimal differences from Firefox
  # D-Bus namespace: uses org.mozilla (not net.mullvad yet)
  # GitLab issue: https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/44050
  # MONITOR: Check if Mullvad Browser changes D-Bus namespace in future releases
  # MONITOR: KDE Plasma 6.8+ may introduce new portal interfaces - verify compatibility
  safeMullvad = mkSandboxedBrowser {
    name = "mullvad-browser";
    package = pkgs.mullvad-browser;
    binaryName = "mullvad-browser";
    dbusOwnName = "org.mozilla.firefox.*";  # Same as Firefox until GitLab issue resolved
  };
  # Desktop entries for sandboxed browsers
  mkBrowserDesktop = { name, exec, icon, comment, genericName ? null }:
    pkgs.makeDesktopItem {
      name = "safe-${name}";
      exec = "${exec} %U";
      icon = icon;
      comment = comment;
      genericName = genericName;
      desktopName = "${name} (Sandboxed)";
      categories = [ "Network" "WebBrowser" ];
      mimeTypes = [ "text/html" "application/xhtml+xml" "application/vnd.mozilla.xul+xml" "http" "https" ];
      startupWMClass = name;
      terminal = false;
      type = "Application";
    };

  safeFirefoxDesktop = mkBrowserDesktop {
    name = "Firefox";
    exec = "safe-firefox";
    icon = "firefox";
    comment = "Hardened Firefox with UID isolation";
    genericName = "Web Browser";
  };

  safeTorDesktop = mkBrowserDesktop {
    name = "Tor Browser";
    exec = "safe-tor-browser";
    icon = "tor-browser";
    comment = "Tor Browser with UID isolation";
    genericName = "Web Browser";
  };

  safeMullvadDesktop = mkBrowserDesktop {
    name = "Mullvad Browser";
    exec = "safe-mullvad-browser";
    icon = "mullvad-browser";
    comment = "Mullvad Browser with UID isolation";
    genericName = "Web Browser";
  };

in {
  environment.systemPackages = lib.optionals config.myOS.security.sandboxedBrowsers.enable [
    safeFirefox safeTor safeMullvad safeFirefoxDesktop safeTorDesktop safeMullvadDesktop
  ];

  programs.firefox = lib.mkIf (!config.myOS.security.sandboxedBrowsers.enable) {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisplayBookmarksToolbar = "never";
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      Preferences = {
        # === MAXIMAL DAILY HARDENING (Arkenfox-aligned) ===
        # Uses FPP (Fingerprinting Protection) with ETP Strict per arkenfox v140+.
        # Aligned preferences: FPI disabled, ETP Strict + TCP enabled, DoH optional
        # Gaming happens in Steam/VRCX, not browser. RFP disabled to reduce breakage.

        # [SECTION 0100]: STARTUP - reduce fingerprinting/telemetry surface
        "browser.startup.page" = 0;  # Blank page
        "browser.startup.homepage" = "about:blank";
        "browser.newtabpage.enabled" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.default.sites" = "";
        "browser.sessionstore.resume_from_crash" = false;

        # [SECTION 0200]: GEOLOCATION - fully disabled
        "geo.enabled" = false;
        "geo.provider.ms-windows-location" = false;
        "geo.provider.use_corelocation" = false;
        "geo.provider.use_gpsd" = false;
        "geo.provider.use_geoclue" = false;

        # [SECTION 0300]: QUIETER FOX - disable all telemetry
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "app.shield.optoutstudies.enabled" = false;
        "app.normandy.enabled" = false;
        "app.normandy.api_url" = "";
        "browser.discovery.enabled" = false;
        "browser.tabs.firefox-view" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "browser.ping-centre.telemetry" = false;
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
        "breakpad.reportURL" = "";
        "browser.tabs.crashReporting.sendReport" = false;

        # [SECTION 0400]: SAFE BROWSING - local only, no remote Google pings
        "browser.safebrowsing.downloads.remote.enabled" = false;
        "browser.safebrowsing.phishing.enabled" = true;
        "browser.safebrowsing.malware.enabled" = true;

        # [SECTION 0600]: BLOCK IMPLICIT OUTBOUND - stop speculative connections
        "network.prefetch-next" = false;
        "network.dns.disablePrefetch" = true;
        "network.dns.disablePrefetchFromHTTPS" = true;
        "network.predictor.enabled" = false;
        "network.http.speculative-parallel-limit" = 0;
        "browser.places.speculativeConnect.enabled" = false;
        "browser.urlbar.speculativeConnect.enabled" = false;

        # [SECTION 0700]: DNS - Use system resolver (VPN DNS when connected)
        # Mullvad recommends using VPN server DNS when connected to VPN.
        # DoH adds latency with negligible security benefit when VPN is active.
        # Daily profile uses system/VPN DNS only - no forced DoH.
        # See: https://mullvad.net/en/help/dns-over-https-and-dns-over-tls
        "network.proxy.socks_remote_dns" = true;
        "network.file.disable_unc_paths" = true;
        "network.gio.supported-protocols" = "";
        "network.trr.mode" = 0;  # DoH disabled - use system/VPN DNS only

        # [SECTION 0800]: LOCATION BAR / SEARCH - disable search suggestions (privacy leak)
        "browser.search.suggest.enabled" = false;
        "browser.urlbar.suggest.searches" = false;

        # [SECTION 1200]: HTTPS / SSL / TLS / CERTS - maximal certificate security
        "dom.security.https_only_mode" = true;
        "dom.security.https_only_mode_ever_enabled" = true;
        "dom.security.https_only_mode_send_http_background_request" = false;
        "security.ssl.require_safe_negotiation" = true;
        "security.ssl.treat_unsafe_negotiation_as_broken" = true;
        "security.tls.enable_0rtt_data" = false;  # Disable 0-RTT (not forward secret)
        "security.OCSP.enabled" = 1;
        "security.OCSP.require" = true;  # Hard-fail on OCSP errors
        "security.cert_pinning.enforcement_level" = 2;  # Strict HPKP
        "security.remote_settings.crlite_filters.enabled" = true;
        "security.pki.crlite_mode" = 2;  # Enforce CRLite
        "browser.xul.error_pages.expert_bad_cert" = true;
        "browser.ssl_override_behavior" = 1;

        # [SECTION 1600]: REFERERS - trim cross-origin referrers
        "network.http.referer.XOriginTrimmingPolicy" = 2;  # Scheme+host+port only

        # [SECTION 1700]: CONTAINERS - enable container tabs for isolation
        "privacy.userContext.enabled" = true;
        "privacy.userContext.ui.enabled" = true;

        # [SECTION 2000]: WEBRTC - COMPROMISE: enabled for gaming/video calls
        # "media.peerconnection.enabled" = false;  # DISABLED: Breaks Discord, VRChat video, streaming
        "media.peerconnection.ice.proxy_only_if_behind_proxy" = true;
        "media.peerconnection.ice.default_address_only" = true;

        # [SECTION 2400]: DOM - arkenfox-aligned: ETP Strict + Total Cookie Protection
        # FPI disabled per arkenfox v96+ guidance. ETP Strict + TCP provides good isolation
        # with less site breakage than FPI. This aligns with upstream recommendations.
        # See: https://github.com/arkenfox/user.js/issues/1345
        "privacy.firstparty.isolate" = false;  # Disabled per arkenfox - use TCP instead
        "browser.contentblocking.category" = "strict";  # ETP Strict
        "privacy.firstparty.isolate.restrict_opener_access" = true;

        # [SECTION 2600]: MISC - various privacy settings
        "network.cookie.cookieBehavior" = 5;  # dFPI + reject cross-site
        # Note: browser.contentblocking.category already set to "strict" above
        "extensions.pocket.enabled" = false;
        "identity.fxaccounts.enabled" = false;  # Firefox Sync
        "extensions.enabledScopes" = 5;  # Limit extension sources
        "extensions.postDownloadThirdPartyPrompt" = false;
        "browser.download.useDownloadDir" = false;  # Ask where to save
        "browser.download.always_ask_before_handling_new_types" = true;

        # [SECTION 2700]: ETP - Enhanced Tracking Protection
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.partition.network_state.ocsp_cache" = true;
        "privacy.partition.serviceWorkers" = true;

        # [SECTION 2800]: SHUTDOWN & SANITIZING - clear data on exit
        "privacy.sanitize.sanitizeOnShutdown" = true;
        "privacy.clearOnShutdown_v2.cache" = true;
        "privacy.clearOnShutdown_v2.cookiesAndStorage" = true;
        "privacy.clearOnShutdown_v2.formdata" = true;
        "privacy.sanitize.timeSpan" = 0;  # Clear everything
        "privacy.clearHistory.cache" = true;
        "privacy.clearHistory.formdata" = true;
        "privacy.clearSiteData.cache" = true;
        "privacy.clearSiteData.formdata" = true;

        # [SECTION 4500]: FINGERPRINTING PROTECTION
        # Arkenfox v140+ now uses FPP (Fingerprinting Protection) by default with ETP Strict.
        # RFP is now optional and causes significant breakage. We use FPP for daily.
        # FPP is automatically enabled with browser.contentblocking.category = "strict" (ETP Strict)
        # See: https://github.com/arkenfox/user.js/releases/latest
        # "privacy.resistFingerprinting" = true;  # DISABLED: Use FPP instead (less breakage)
        # "privacy.resistFingerprinting.letterboxing" = true;

        # [SECTION 8500]: CAPTIVE PORTAL - disable connectivity checks
        "captivedetect.canonicalURL" = "";
        "network.captive-portal-service.enabled" = false;
        "network.connectivity-service.enabled" = false;
      };
    };
  };
}
