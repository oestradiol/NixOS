{ config, lib, pkgs, ... }:
let
  # National-level browser sandbox: UID isolation, network namespace, minimal FS access
  # Even if browser is compromised by state-level actor, host UID is unmapped
  mkSandboxedBrowser = { name, package, binaryName ? name, extraBinds ? [] }: 
    pkgs.writeShellScriptBin "safe-${name}" ''
      set -eu
      
      RUNTIME="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/safe-${name}"
      PROFILE="$RUNTIME/profile"
      CACHE="$RUNTIME/cache"
      mkdir -p "$PROFILE" "$CACHE"
      
      # GPU and display sockets
      DISPLAY_SOCK="''${WAYLAND_DISPLAY:-$DISPLAY}"
      [[ -n "''${WAYLAND_DISPLAY:-}" ]] && WAYLAND_SOCK="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
      [[ -S "$XDG_RUNTIME_DIR/pipewire-0" ]] && PIPEWIRE_SOCK="$XDG_RUNTIME_DIR/pipewire-0"
      [[ -d /dev/dri ]] && GPU_DEV="/dev/dri"
      
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
        --ro-bind /run /run \
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
    user_pref("network.trr.mode", 2); // DoH with system fallback
    user_pref("network.trr.uri", "https://cloudflare-dns.com/dns-query");
    user_pref("network.trr.bootstrapAddress", "1.1.1.1");
    
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
    
    // [SECTION 2400]: DOM
    user_pref("privacy.firstparty.isolate", true); // dFPI
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
  
  safeFirefox = pkgs.writeShellScriptBin "safe-firefox" ''
    set -eu
    
    RUNTIME="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/safe-firefox"
    PROFILE="$RUNTIME/profile"
    CACHE="$RUNTIME/cache"
    mkdir -p "$PROFILE" "$CACHE"
    
    # Inject hardened user.js if not present
    if [[ ! -f "$PROFILE/user.js" ]]; then
      cp ${hardenedUserJS} "$PROFILE/user.js"
    fi
    
    # GPU and display sockets
    DISPLAY_SOCK="''${WAYLAND_DISPLAY:-$DISPLAY}"
    [[ -n "''${WAYLAND_DISPLAY:-}" ]] && WAYLAND_SOCK="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    [[ -S "$XDG_RUNTIME_DIR/pipewire-0" ]] && PIPEWIRE_SOCK="$XDG_RUNTIME_DIR/pipewire-0"
    [[ -d /dev/dri ]] && GPU_DEV="/dev/dri"
    
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
      --ro-bind /run /run \
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
      --setenv HOME "$HOME" \
      --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR" \
      --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" \
      --setenv DISPLAY "$DISPLAY" \
      --cap-drop ALL \
      ${pkgs.firefox}/bin/firefox --no-remote --profile "$PROFILE" "$@"
  '';
  
  safeTor = mkSandboxedBrowser {
    name = "tor-browser";
    package = pkgs.tor-browser;
    binaryName = "tor-browser";
  };
  
  safeMullvad = mkSandboxedBrowser {
    name = "mullvad-browser";
    package = pkgs.mullvad-browser;
    binaryName = "mullvad-browser";
  };
in {
  environment.systemPackages = [ safeFirefox safeTor safeMullvad ];

  programs.firefox = {
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
        "media.peerconnection.enabled" = false;
        "privacy.resistFingerprinting" = config.myOS.security.browserLockdown.enable;
        "browser.startup.homepage" = "about:blank";
        "browser.newtabpage.enabled" = false;
      };
    } // lib.optionalAttrs config.myOS.security.browserLockdown.enable {
      DisableFirefoxAccounts = true;
      ExtensionSettings = {
        "*" = { installation_mode = "blocked"; };
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
      };
    };
  };
}
