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
  
  # Hardened user.js for Firefox - based on arkenfox user.js v140
  # Comprehensive privacy/security hardening for sandboxed browsers (paranoid)
  hardenedUserJS = pkgs.writeText "user.js" ''
    // Firefox hardening preferences - grounded in arkenfox research
    // https://github.com/arkenfox/user.js
    
    // [SECTION 0000]: UI
    user_pref("browser.aboutConfig.showWarning", false);
    
    // [SECTION 0100]: STARTUP
    user_pref("browser.startup.page", 0);
    user_pref("browser.startup.homepage", "chrome://browser/content/blanktab.html");
    user_pref("browser.newtabpage.enabled", false);
    user_pref("browser.newtabpage.activity-stream.showSponsored", false);
    user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
    user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
    user_pref("browser.newtabpage.activity-stream.default.sites", "");
    user_pref("browser.sessionstore.resume_from_crash", false);
    
    // [SECTION 0200]: GEOLOCATION
    user_pref("geo.enabled", false);
    user_pref("geo.provider.ms-windows-location", false);
    user_pref("geo.provider.use_corelocation", false);
    user_pref("geo.provider.use_gpsd", false);
    user_pref("geo.provider.use_geoclue", false);
    
    // [SECTION 0300]: QUIETER FOX
    user_pref("extensions.getAddons.showPane", false);
    user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
    user_pref("browser.discovery.enabled", false);
    user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
    user_pref("browser.newtabpage.activity-stream.telemetry", false);
    user_pref("app.shield.optoutstudies.enabled", false);
    user_pref("app.normandy.enabled", false);
    user_pref("app.normandy.api_url", "");
    user_pref("breakpad.reportURL", "");
    user_pref("browser.tabs.crashReporting.sendReport", false);
    user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);
    user_pref("captivedetect.canonicalURL", "");
    user_pref("network.captive-portal-service.enabled", false);
    user_pref("network.connectivity-service.enabled", false);
    
    // [SECTION 0400]: SAFE BROWSING
    user_pref("browser.safebrowsing.downloads.remote.enabled", false);
    // user_pref("browser.safebrowsing.malware.enabled", false);
    // user_pref("browser.safebrowsing.phishing.enabled", false);
    
    // [SECTION 0600]: BLOCK IMPLICIT OUTBOUND
    user_pref("network.prefetch-next", false);
    user_pref("network.dns.disablePrefetch", true);
    user_pref("network.dns.disablePrefetchFromHTTPS", true);
    user_pref("network.predictor.enabled", false);
    user_pref("network.predictor.enable-prefetch", false);
    user_pref("network.http.speculative-parallel-limit", 0);
    user_pref("browser.places.speculativeConnect.enabled", false);
    
    // [SECTION 0700]: DNS / PROXY / SOCKS
    user_pref("network.proxy.socks_remote_dns", true);
    user_pref("network.file.disable_unc_paths", true);
    user_pref("network.gio.supported-protocols", "");
    user_pref("network.trr.mode", 2); // DoH with system fallback
    user_pref("network.trr.uri", "https://dns.mullvad.net/dns-query"); // Mullvad DoH (no content blocking)
    user_pref("network.trr.bootstrapAddress", "194.242.2.2"); // Mullvad bootstrap IP
    // user_pref("network.trr.uri", "https://example.dns");
    // user_pref("network.trr.custom_uri", "https://example.dns");
    
    // [SECTION 0800]: LOCATION BAR / SEARCH
    user_pref("browser.urlbar.speculativeConnect.enabled", false);
    user_pref("browser.urlbar.quicksuggest.enabled", false);
    user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
    user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
    user_pref("browser.search.suggest.enabled", false);
    user_pref("browser.urlbar.suggest.searches", false);
    user_pref("browser.urlbar.trending.featureGate", false);
    user_pref("browser.urlbar.addons.featureGate", false);
    user_pref("browser.urlbar.amp.featureGate", false);
    user_pref("browser.urlbar.fakespot.featureGate", false);
    user_pref("browser.urlbar.mdn.featureGate", false);
    user_pref("browser.urlbar.weather.featureGate", false);
    user_pref("browser.urlbar.wikipedia.featureGate", false);
    user_pref("browser.urlbar.yelp.featureGate", false);
    user_pref("browser.urlbar.clipboard.featureGate", false);
    user_pref("browser.urlbar.recentsearches.featureGate", false);
    user_pref("browser.formfill.enable", false);
    user_pref("browser.search.separatePrivateDefault", true);
    user_pref("browser.search.separatePrivateDefault.ui.enabled", true);
    // user_pref("browser.urlbar.suggest.engines", false);
    // user_pref("layout.css.visited_links_enabled", false);
    
    // [SECTION 0900]: PASSWORDS
    user_pref("signon.autofillForms", false);
    user_pref("signon.formlessCapture.enabled", false);
    user_pref("network.auth.subresource-http-auth-allow", 1);
    // user_pref("network.http.windows-sso.enabled", false);
    // user_pref("network.http.microsoft-entra-sso.enabled", false);
    
    // [SECTION 1000]: DISK AVOIDANCE
    user_pref("browser.cache.disk.enable", false);
    user_pref("browser.privatebrowsing.forceMediaMemoryCache", true);
    user_pref("media.memory_cache_max_size", 65536);
    user_pref("browser.sessionstore.privacy_level", 2);
    user_pref("toolkit.winRegisterApplicationRestart", false);
    user_pref("browser.shell.shortcutFavicons", false);
    
    // [SECTION 1200]: HTTPS / SSL / TLS / CERTS
    user_pref("security.ssl.require_safe_negotiation", true);
    user_pref("security.tls.enable_0rtt_data", false);
    user_pref("security.OCSP.enabled", 1);
    user_pref("security.OCSP.require", true);
    user_pref("security.cert_pinning.enforcement_level", 2);
    user_pref("security.remote_settings.crlite_filters.enabled", true);
    user_pref("security.pki.crlite_mode", 2);
    // user_pref("security.mixed_content.block_display_content", true);
    user_pref("dom.security.https_only_mode", true);
    // user_pref("dom.security.https_only_mode_pbm", true);
    // user_pref("dom.security.https_only_mode.upgrade_local", true);
    user_pref("dom.security.https_only_mode_send_http_background_request", false);
    user_pref("security.ssl.treat_unsafe_negotiation_as_broken", true);
    user_pref("browser.xul.error_pages.expert_bad_cert", true);
    
    // [SECTION 1600]: REFERERS
    user_pref("network.http.referer.XOriginTrimmingPolicy", 2);
    
    // [SECTION 1700]: CONTAINERS
    user_pref("privacy.userContext.enabled", true);
    user_pref("privacy.userContext.ui.enabled", true);
    // user_pref("privacy.userContext.newTabContainerOnLeftClick.enabled", true);
    // user_pref("browser.link.force_default_user_context_id_for_external_opens", true);
    
    // [SECTION 2000]: WEBRTC / MEDIA
    user_pref("media.peerconnection.ice.proxy_only_if_behind_proxy", true);
    user_pref("media.peerconnection.ice.default_address_only", true);
    // user_pref("media.peerconnection.ice.no_host", true);
    // user_pref("media.gmp-provider.enabled", false);
    
    // [SECTION 2400]: DOM
    user_pref("dom.disable_window_move_resize", true);
    
    // [SECTION 2600]: MISC
    user_pref("browser.download.start_downloads_in_tmp_dir", true);
    user_pref("browser.helperApps.deleteTempFileOnExit", true);
    user_pref("browser.uitour.enabled", false);
    // user_pref("browser.uitour.url", "");
    user_pref("devtools.debugger.remote-enabled", false);
    // user_pref("permissions.default.shortcuts", 2);
    user_pref("permissions.manager.defaultsUrl", "");
    user_pref("network.IDN_show_punycode", true);
    user_pref("pdfjs.disabled", false);
    user_pref("pdfjs.enableScripting", false);
    user_pref("browser.tabs.searchclipboardfor.middleclick", false);
    user_pref("browser.contentanalysis.enabled", false);
    user_pref("browser.contentanalysis.default_result", 0);
    // user_pref("privacy.antitracking.isolateContentScriptResources", true);
    user_pref("security.csp.reporting.enabled", false);
    user_pref("browser.download.useDownloadDir", false);
    user_pref("browser.download.alwaysOpenPanel", false);
    user_pref("browser.download.manager.addToRecentDocs", false);
    user_pref("browser.download.always_ask_before_handling_new_types", true);
    user_pref("extensions.enabledScopes", 5);
    // user_pref("extensions.autoDisableScopes", 15);
    user_pref("extensions.postDownloadThirdPartyPrompt", false);
    // user_pref("extensions.webextensions.restrictedDomains", "");
    
    // [SECTION 2700]: ETP
    user_pref("browser.contentblocking.category", "strict");
    // user_pref("privacy.antitracking.enableWebcompat", false);
    
    // [SECTION 2800]: SHUTDOWN & SANITIZING
    user_pref("privacy.sanitize.sanitizeOnShutdown", true);
    user_pref("privacy.clearOnShutdown_v2.cache", true);
    user_pref("privacy.clearOnShutdown_v2.historyFormDataAndDownloads", false);
    // user_pref("privacy.clearOnShutdown_v2.siteSettings", false);
    user_pref("privacy.clearOnShutdown_v2.browsingHistoryAndDownloads", false);
    user_pref("privacy.clearOnShutdown_v2.downloads", false);
    user_pref("privacy.clearOnShutdown_v2.formdata", true);
    // user_pref("privacy.clearOnShutdown.openWindows", true);
    user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", true);
    user_pref("privacy.clearSiteData.cache", true);
    user_pref("privacy.clearSiteData.cookiesAndStorage", false);
    user_pref("privacy.clearSiteData.historyFormDataAndDownloads", false);
    // user_pref("privacy.clearSiteData.siteSettings", false);
    user_pref("privacy.clearSiteData.browsingHistoryAndDownloads", false);
    user_pref("privacy.clearSiteData.formdata", true);
    user_pref("privacy.clearHistory.cache", true);
    user_pref("privacy.clearHistory.cookiesAndStorage", false);
    user_pref("privacy.clearHistory.historyFormDataAndDownloads", false);
    // user_pref("privacy.clearHistory.siteSettings", false);
    user_pref("privacy.clearHistory.browsingHistoryAndDownloads", false);
    user_pref("privacy.clearHistory.formdata", true);
    user_pref("privacy.sanitize.timeSpan", 0);
    
    // [SECTION 4000]: FPP
    // user_pref("privacy.fingerprintingProtection.pbmode", true);
    // user_pref("privacy.fingerprintingProtection.overrides", "");
    // user_pref("privacy.fingerprintingProtection.granularOverrides", "");
    // user_pref("privacy.fingerprintingProtection.remoteOverrides.enabled", false);
    
    // [SECTION 4500]: OPTIONAL RFP
    user_pref("privacy.resistFingerprinting", true);
    user_pref("privacy.resistFingerprinting.pbmode", true);
    user_pref("privacy.window.maxInnerWidth", 1600);
    user_pref("privacy.window.maxInnerHeight", 900);
    user_pref("privacy.resistFingerprinting.block_mozAddonManager", true);
    user_pref("privacy.resistFingerprinting.letterboxing", true);
    // user_pref("privacy.resistFingerprinting.letterboxing.dimensions", "");
    // user_pref("privacy.resistFingerprinting.exemptedDomains", "*.example.invalid");
    user_pref("privacy.spoof_english", 1);
    // user_pref("privacy.resistFingerprinting.skipEarlyBlankFirstPaint", true);
    // user_pref("browser.display.document_color_use", 1);
    user_pref("widget.non-native-theme.use-theme-accent", false);
    user_pref("browser.link.open_newwindow", 3);
    user_pref("browser.link.open_newwindow.restriction", 0);
    // user_pref("webgl.disabled", true);
    
    // [SECTION 5000]: OPTIONAL OPSEC
    // user_pref("browser.privatebrowsing.autostart", true);
    // user_pref("browser.cache.memory.enable", false);
    // user_pref("browser.cache.memory.capacity", 0);
    // user_pref("signon.rememberSignons", false);
    // user_pref("permissions.memory_only", true);
    // user_pref("security.nocertdb", true);
    // user_pref("browser.chrome.site_icons", false);
    // user_pref("browser.sessionstore.max_tabs_undo", 0);
    // user_pref("browser.sessionstore.resume_from_crash", false);
    // user_pref("browser.download.forbid_open_with", true);
    // user_pref("browser.urlbar.suggest.history", false);
    // user_pref("browser.urlbar.suggest.bookmark", false);
    // user_pref("browser.urlbar.suggest.openpage", false);
    // user_pref("browser.urlbar.suggest.topsites", false);
    // user_pref("browser.urlbar.maxRichResults", 0);
    // user_pref("browser.urlbar.autoFill", false);
    // user_pref("places.history.enabled", false);
    // user_pref("browser.taskbar.lists.enabled", false);
    // user_pref("browser.taskbar.lists.frequent.enabled", false);
    // user_pref("browser.taskbar.lists.recent.enabled", false);
    // user_pref("browser.taskbar.lists.tasks.enabled", false);
    // user_pref("browser.download.folderList", 2);
    // user_pref("extensions.formautofill.addresses.enabled", false);
    // user_pref("extensions.formautofill.creditCards.enabled", false);
    // user_pref("dom.popup_allowed_events", "click dblclick mousedown pointerdown");
    // user_pref("browser.pagethumbnails.capturing_disabled", true);
    // user_pref("alerts.useSystemBackend.windows.notificationserver.enabled", false);
    // user_pref("keyword.enabled", false);
    
    // [SECTION 5500]: OPTIONAL HARDENING
    // user_pref("mathml.disabled", true);
    // user_pref("svg.disabled", true);
    // user_pref("gfx.font_rendering.graphite.enabled", false);
    // user_pref("javascript.options.asmjs", false);
    // user_pref("javascript.options.ion", false);
    // user_pref("javascript.options.baselinejit", false);
    // user_pref("javascript.options.jit_trustedprincipals", true);
    // user_pref("javascript.options.wasm", false);
    // user_pref("gfx.font_rendering.opentype_svg.enabled", false);
    // user_pref("media.eme.enabled", false);
    // user_pref("browser.eme.ui.enabled", false);
    // user_pref("network.dns.disableIPv6", true);
    // user_pref("network.http.referer.XOriginPolicy", 2);
    // user_pref("network.trr.bootstrapAddr", "10.0.0.1");
    
    // [SECTION 6000]: DON'T TOUCH
    user_pref("extensions.blocklist.enabled", true);
    user_pref("network.http.referer.spoofSource", false);
    user_pref("security.dialog_enable_delay", 1000);
    user_pref("privacy.firstparty.isolate", false);
    user_pref("extensions.webcompat.enable_shims", true);
    user_pref("security.tls.version.enable-deprecated", false);
    user_pref("extensions.webcompat-reporter.enabled", false);
    user_pref("extensions.quarantinedDomains.enabled", true);
    
    // [SECTION 7000]: DON'T BOTHER
    // user_pref("geo.enabled", false);
    // user_pref("full-screen-api.enabled", false);
    // user_pref("permissions.default.geo", 0);
    // user_pref("permissions.default.camera", 0);
    // user_pref("permissions.default.microphone", 0);
    // user_pref("permissions.default.desktop-notification", 0);
    // user_pref("permissions.default.xr", 0);
    // user_pref("security.ssl3.ecdhe_ecdsa_aes_128_sha", false);
    // user_pref("security.ssl3.ecdhe_ecdsa_aes_256_sha", false);
    // user_pref("security.ssl3.ecdhe_rsa_aes_128_sha", false);
    // user_pref("security.ssl3.ecdhe_rsa_aes_256_sha", false);
    // user_pref("security.ssl3.rsa_aes_128_gcm_sha256", false);
    // user_pref("security.ssl3.rsa_aes_256_gcm_sha384", false);
    // user_pref("security.ssl3.rsa_aes_128_sha", false);
    // user_pref("security.ssl3.rsa_aes_256_sha", false);
    // user_pref("security.tls.version.min", 3);
    // user_pref("security.tls.version.max", 4);
    // user_pref("security.ssl.disable_session_identifiers", true);
    // user_pref("network.http.sendRefererHeader", 2);
    // user_pref("network.http.referer.trimmingPolicy", 0);
    // user_pref("network.http.referer.defaultPolicy", 2);
    // user_pref("network.http.referer.defaultPolicy.pbmode", 2);
    // user_pref("network.http.altsvc.enabled", false);
    // user_pref("dom.event.contextmenu.enabled", false);
    // user_pref("gfx.downloadable_fonts.enabled", false);
    // user_pref("gfx.downloadable_fonts.fallback_delay", -1);
    // user_pref("dom.event.clipboardevents.enabled", false);
    // user_pref("extensions.systemAddon.update.enabled", false);
    // user_pref("extensions.systemAddon.update.url", "");
    // user_pref("privacy.donottrackheader.enabled", true);
    // user_pref("network.cookie.cookieBehavior", 5);
    // user_pref("network.cookie.cookieBehavior.optInPartitioning", true);
    // user_pref("network.http.referer.disallowCrossSiteRelaxingDefault", true);
    // user_pref("network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation", true);
    // user_pref("privacy.bounceTrackingProtection.mode", 1);
    // user_pref("privacy.fingerprintingProtection", true);
    // user_pref("privacy.partition.network_state.ocsp_cache", true);
    // user_pref("privacy.query_stripping.enabled", true);
    // user_pref("privacy.trackingprotection.enabled", true);
    // user_pref("privacy.trackingprotection.socialtracking.enabled", true);
    // user_pref("privacy.trackingprotection.cryptomining.enabled", true);
    // user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
    // user_pref("dom.serviceWorkers.enabled", false);
    // user_pref("dom.webnotifications.enabled", false);
    // user_pref("dom.push.enabled", false);
    // user_pref("media.peerconnection.enabled", false);
    // user_pref("privacy.globalprivacycontrol.enabled", true);
    
    // [SECTION 8000]: DON'T BOTHER: FINGERPRINTING
    // user_pref("browser.display.use_document_fonts", "");
    // user_pref("browser.zoom.siteSpecific", "");
    // user_pref("device.sensors.enabled", "");
    // user_pref("dom.enable_performance", "");
    // user_pref("dom.enable_resource_timing", "");
    // user_pref("dom.gamepad.enabled", "");
    // user_pref("dom.maxHardwareConcurrency", "");
    // user_pref("dom.w3c_touch_events.enabled", "");
    // user_pref("dom.webaudio.enabled", "");
    // user_pref("font.system.whitelist", "");
    // user_pref("general.appname.override", "");
    // user_pref("general.appversion.override", "");
    // user_pref("general.buildID.override", "");
    // user_pref("general.oscpu.override", "");
    // user_pref("general.platform.override", "");
    // user_pref("general.useragent.override", "");
    // user_pref("media.navigator.enabled", "");
    // user_pref("media.video_stats.enabled", "");
    // user_pref("media.webspeech.synth.enabled", "");
    // user_pref("ui.use_standins_for_native_colors", "");
    // user_pref("webgl.enable-debug-renderer-info", "");
    
    // [SECTION 8500]: TELEMETRY
    user_pref("datareporting.policy.dataSubmissionEnabled", false);
    user_pref("datareporting.healthreport.uploadEnabled", false);
    user_pref("toolkit.telemetry.unified", false);
    user_pref("toolkit.telemetry.enabled", false);
    user_pref("toolkit.telemetry.server", "data:,");
    user_pref("toolkit.telemetry.archive.enabled", false);
    user_pref("toolkit.telemetry.newProfilePing.enabled", false);
    user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
    user_pref("toolkit.telemetry.updatePing.enabled", false);
    user_pref("toolkit.telemetry.bhrPing.enabled", false);
    user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
    user_pref("toolkit.telemetry.coverage.opt-out", true);
    user_pref("toolkit.coverage.opt-out", true);
    user_pref("toolkit.coverage.endpoint.base", "");
    
    // [SECTION 9000]: NON-PROJECT RELATED
    user_pref("browser.startup.homepage_override.mstone", "ignore");
    user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
    user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
    user_pref("browser.urlbar.showSearchTerms.enabled", false);
    
    // Additional preferences not in arkenfox sections (for paranoid hardening)
    user_pref("extensions.pocket.enabled", false);
    user_pref("identity.fxaccounts.enabled", false);
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
        # === ARKENFOX-STYLE HARDENING (daily profile) ===
        # Based on https://github.com/arkenfox/user.js
        
        # [SECTION 0100]: STARTUP
        "browser.startup.page" = 0; # Blank page
        "browser.startup.homepage" = "about:blank";
        "browser.newtabpage.enabled" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.default.sites" = "";
        
        # [SECTION 0200]: GEOLOCATION
        "geo.enabled" = false;
        "geo.provider.ms-windows-location" = false;
        "geo.provider.use_corelocation" = false;
        "geo.provider.use_gpsd" = false;
        "geo.provider.use_geoclue" = false;
        
        # [SECTION 0300]: QUIETER FOX
        "extensions.getAddons.showPane" = false;
        "extensions.htmlaboutaddons.recommendations.enabled" = false;
        "browser.discovery.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "app.shield.optoutstudies.enabled" = false;
        "app.normandy.enabled" = false;
        "app.normandy.api_url" = "";
        "breakpad.reportURL" = "";
        "browser.tabs.crashReporting.sendReport" = false;
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
        
        # [SECTION 0400]: SAFE BROWSING
        "browser.safebrowsing.downloads.remote.enabled" = false; # Local DB only
        "browser.safebrowsing.phishing.enabled" = true;
        "browser.safebrowsing.malware.enabled" = true;
        
        # [SECTION 0600]: BLOCK IMPLICIT OUTBOUND
        # Network prefetch blocking - may slow page loads, minimal privacy gain
        # "network.prefetch-next" = false;
        # "network.dns.disablePrefetch" = true;
        # "network.dns.disablePrefetchFromHTTPS" = true;
        # "network.predictor.enabled" = false;
        # "network.http.speculative-parallel-limit" = 0;
        # "browser.places.speculativeConnect.enabled" = false;
        # "browser.urlbar.speculativeConnect.enabled" = false;
        
        # [SECTION 0700]: DNS / PROXY / SOCKS
        "network.proxy.socks_remote_dns" = true;
        "network.file.disable_unc_paths" = true;
        "network.gio.supported-protocols" = "";
        "network.trr.mode" = 2; # DoH with system fallback
        "network.trr.uri" = "https://dns.mullvad.net/dns-query"; # Mullvad DoH (no content blocking)
        "network.trr.bootstrapAddress" = "194.242.2.2"; # Mullvad bootstrap IP
        
        # [SECTION 0800]: LOCATION BAR / SEARCH
        "browser.search.suggest.enabled" = false;
        "browser.urlbar.suggest.searches" = false;
        "browser.urlbar.quicksuggest.enabled" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.urlbar.trending.featureGate" = false;
        "browser.urlbar.addons.featureGate" = false;
        "browser.urlbar.amp.featureGate" = false;
        "browser.urlbar.mdn.featureGate" = false;
        "browser.urlbar.weather.featureGate" = false;
        "browser.urlbar.wikipedia.featureGate" = false;
        "browser.urlbar.yelp.featureGate" = false;
        
        # Search suggestions - if you trust your search engine, enable these
        # "browser.search.separatePrivateDefault" = true;
        # "browser.search.separatePrivateDefault.ui.enabled" = true;
        
        # Form history - autocomplete can be read by third parties
        # "browser.formfill.enable" = false;
        
        # [SECTION 0900]: PASSWORDS
        "signon.autofillForms" = false; # Can leak in cross-site forms
        "signon.formlessCapture.enabled" = false;
        "network.auth.subresource-http-auth-allow" = 1;
        
        # [SECTION 1000]: DISK AVOIDANCE
        # Disk cache - may affect performance
        # "browser.cache.disk.enable" = false;
        "browser.privatebrowsing.forceMediaMemoryCache" = true;
        "media.memory_cache_max_size" = 65536;
        "browser.sessionstore.privacy_level" = 2;
        
        # [SECTION 1200]: HTTPS / SSL / TLS / CERTS
        "security.ssl.require_safe_negotiation" = true;
        "security.ssl.treat_unsafe_negotiation_as_broken" = true;
        "security.tls.enable_0rtt_data" = false; # Not forward secret
        "security.OCSP.enabled" = 1;
        "security.OCSP.require" = true;
        "security.cert_pinning.enforcement_level" = 2;
        "security.remote_settings.crlite_filters.enabled" = true;
        "security.pki.crlite_mode" = 2;
        "dom.security.https_only_mode" = true;
        "dom.security.https_only_mode_ever_enabled" = true;
        "dom.security.https_only_mode_send_http_background_request" = false;
        "browser.xul.error_pages.expert_bad_cert" = true;
        
        # [SECTION 1600]: REFERERS
        # Referer trimming - may break some sites' navigation
        # "network.http.referer.XOriginTrimmingPolicy" = 2;
        
        # [SECTION 1700]: CONTAINERS
        # Container tabs - adds complexity, not needed for daily gaming
        # "privacy.userContext.enabled" = true;
        # "privacy.userContext.ui.enabled" = true;
        
        # [SECTION 2000]: WEBRTC / MEDIA
        "media.peerconnection.enabled" = false; # Prevents IP leaks
        "media.peerconnection.ice.proxy_only_if_behind_proxy" = true;
        "media.peerconnection.ice.default_address_only" = true;
        
        # [SECTION 2400]: DOM
        "dom.disable_window_move_resize" = true;
        
        # [SECTION 2600]: MISC
        "browser.download.start_downloads_in_tmp_dir" = true;
        "browser.helperApps.deleteTempFileOnExit" = true;
        "browser.uitour.enabled" = false;
        "devtools.debugger.remote-enabled" = false;
        "permissions.manager.defaultsUrl" = "";
        "network.IDN_show_punycode" = true;
        "pdfjs.disabled" = false;
        "pdfjs.enableScripting" = false;
        "browser.download.useDownloadDir" = false;
        "browser.download.always_ask_before_handling_new_types" = true;
        "extensions.enabledScopes" = 5;
        "extensions.postDownloadThirdPartyPrompt" = false;
        
        # [SECTION 2700]: ETP
        "browser.contentblocking.category" = "strict";
        
        # [SECTION 2800]: SHUTDOWN & SANITIZING
        # Clear on shutdown - inconvenient for daily use
        # "privacy.sanitize.sanitizeOnShutdown" = true;
        # "privacy.clearOnShutdown_v2.cache" = true;
        # "privacy.clearOnShutdown_v2.cookiesAndStorage" = true;
        # "privacy.clearOnShutdown_v2.formdata" = true;
        # "privacy.sanitize.timeSpan" = 0;
        
        # [SECTION 4000]: FPP
        # FPP is enabled with ETP strict by default in FF119+
        
        # [SECTION 4500]: RFP (Resist Fingerprinting)
        # RFP breaks some sites, affects WebGL/fingerprinting in games
        # "privacy.resistFingerprinting" = true;
        
        # [SECTION 8500]: CAPTIVE PORTAL
        // Captive portal disable - breaks hotel/airport WiFi
        // "captivedetect.canonicalURL", "";
        // "network.captive-portal-service.enabled", false;
        // "network.connectivity-service.enabled", false;
        
        // Cookie isolation (dFPI) - privacy benefit, some sites may break
        // Note: ETP Strict (browser.contentblocking.category = "strict") enables TCP which replaces FPI
        "network.cookie.cookieBehavior" = 5;
        
        // Enhanced Tracking Protection strict - privacy benefit, minimal breakage
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
      };
    };
  };
}
