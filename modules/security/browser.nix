{ config, lib, pkgs, ... }:
let
  cfg = config.myOS.security.sandbox;
  browsersEnabled = cfg.browsers;
  core = import ./sandbox-core.nix { inherit lib pkgs; };
  arkenfoxBase = builtins.readFile ./arkenfox/user.js;

  mkUserJs = { profileName, resistFingerprinting, letterboxing, webglDisabled, extraPrefs ? "" }:
    pkgs.writeText "${profileName}-user.js" ''
      // Repo baseline: vendored arkenfox snapshot plus repo overrides.
      // Source file: modules/security/arkenfox/user.js
      // Do not edit the vendored file in place; append repo overrides here.
      ${arkenfoxBase}

      /* repo override block */
      user_pref("privacy.fingerprintingProtection", true);
      user_pref("privacy.resistFingerprinting", ${if resistFingerprinting then "true" else "false"});
      user_pref("privacy.resistFingerprinting.pbmode", ${if resistFingerprinting then "true" else "false"});
      user_pref("privacy.resistFingerprinting.letterboxing", ${if letterboxing then "true" else "false"});
      user_pref("webgl.disabled", ${if webglDisabled then "true" else "false"});
      ${extraPrefs}
    '';

  dailyFirefoxUserJS = mkUserJs {
    profileName = "daily-firefox";
    resistFingerprinting = false;
    letterboxing = false;
    webglDisabled = false;
    extraPrefs = ''
      // Daily relaxations: keep arkenfox-derived baseline but relax only what daily needs.
      user_pref("browser.startup.page", 0);
      user_pref("browser.startup.homepage", "about:blank");
      user_pref("browser.newtabpage.enabled", false);
      user_pref("browser.newtabpage.activity-stream.showSponsored", false);
      user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
      user_pref("browser.discovery.enabled", false);
      user_pref("browser.urlbar.quicksuggest.enabled", false);
      user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
      user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
      user_pref("toolkit.telemetry.enabled", false);
      user_pref("toolkit.telemetry.unified", false);
      user_pref("toolkit.telemetry.archive.enabled", false);
      user_pref("datareporting.healthreport.uploadEnabled", false);
      user_pref("datareporting.policy.dataSubmissionEnabled", false);
      user_pref("app.shield.optoutstudies.enabled", false);
      user_pref("app.normandy.enabled", false);
      user_pref("app.normandy.api_url", "");
      user_pref("geo.enabled", false);
      user_pref("network.trr.mode", 5);
      user_pref("privacy.donottrackheader.enabled", true);
      user_pref("privacy.globalprivacycontrol.enabled", true);
      user_pref("network.cookie.cookieBehavior", 5);
      user_pref("network.http.referer.XOriginTrimmingPolicy", 2);
      user_pref("browser.safebrowsing.downloads.remote.enabled", false);
      // Keep local malware/phishing protection on daily for usability; arkenfox leaves room for operator choice here.
      user_pref("browser.safebrowsing.phishing.enabled", true);
      user_pref("browser.safebrowsing.malware.enabled", true);
      // Daily usability constraints: keep WebRTC functional for streaming/social use.
      user_pref("media.peerconnection.enabled", true);
      user_pref("media.navigator.enabled", true);
      // Daily usability constraints: allow session restore and normal logins.
      user_pref("browser.sessionstore.resume_from_crash", true);
      user_pref("privacy.clearOnShutdown_v2.historyFormDataAndDownloads", false);
      user_pref("privacy.clearOnShutdown_v2.browsingHistoryAndDownloads", false);
    '';
  };

  paranoidFirefoxUserJS = mkUserJs {
    profileName = "safe-firefox";
    resistFingerprinting = true;
    letterboxing = true;
    webglDisabled = true;
    extraPrefs = ''
      // Paranoid path: start from vendored arkenfox, then tighten only where still within repo constraints.
      user_pref("browser.startup.page", 0);
      user_pref("browser.startup.homepage", "about:blank");
      user_pref("browser.newtabpage.enabled", false);
      user_pref("browser.discovery.enabled", false);
      user_pref("browser.urlbar.quicksuggest.enabled", false);
      user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
      user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
      user_pref("toolkit.telemetry.enabled", false);
      user_pref("toolkit.telemetry.unified", false);
      user_pref("toolkit.telemetry.archive.enabled", false);
      user_pref("datareporting.healthreport.uploadEnabled", false);
      user_pref("datareporting.policy.dataSubmissionEnabled", false);
      user_pref("app.shield.optoutstudies.enabled", false);
      user_pref("app.normandy.enabled", false);
      user_pref("app.normandy.api_url", "");
      user_pref("geo.enabled", false);
      user_pref("network.trr.mode", 5);
      user_pref("privacy.donottrackheader.enabled", true);
      user_pref("privacy.globalprivacycontrol.enabled", true);
      user_pref("browser.safebrowsing.downloads.remote.enabled", false);
      // Keep networked-browser functionality, but do not relax RFP/letterboxing/WebGL.
      user_pref("media.peerconnection.enabled", true);
      user_pref("media.navigator.enabled", true);
    '';
  };

  mkBrowser = {
    name,
    package,
    binaryName ? name,
    dbusOwnName ? null,
    userJs ? null,
    extraArgs ? [ ],
    extraSetup ? "",
  }:
    core.mkSandboxWrapper {
      inherit name package binaryName;
      network = true;
      gpu = cfg.gpu;
      enableDbusProxy = cfg.dbusFilter;
      wayland = cfg.wayland;
      x11 = cfg.x11;
      pipewire = cfg.pipewire;
      sessionBusTalk = lib.optionals cfg.dbusFilter (
        lib.optionals cfg.portals [ "org.freedesktop.portal.*" ] ++ [
          "org.a11y.Bus"
          "org.mpris.MediaPlayer2.*"
        ]
      );
      sessionBusOwn = lib.optionals (cfg.dbusFilter && dbusOwnName != null) [ dbusOwnName ];
      sessionBusBroadcast = lib.optionals (cfg.dbusFilter && cfg.portals) [
        "org.freedesktop.portal.*=@/org/freedesktop/portal/*"
      ];
      extraSetup = ''
        ${lib.optionalString (userJs != null) ''
          mkdir -p "$SANDBOX_HOME/${name}-profile"
          cp ${userJs} "$SANDBOX_HOME/${name}-profile/user.js"
        ''}
        ${extraSetup}
      '';
      args = extraArgs ++ lib.optionals (userJs != null) [ "--profile" "/home/sandbox/${name}-profile" ];
    };

  safeFirefox = mkBrowser {
    name = "firefox";
    package = pkgs.firefox;
    binaryName = "firefox";
    dbusOwnName = "org.mozilla.firefox.*";
    userJs = paranoidFirefoxUserJS;
    extraArgs = [ "--no-remote" ];
  };

  safeTor = mkBrowser {
    name = "tor-browser";
    package = pkgs.tor-browser;
    binaryName = "firefox";
    extraArgs = [ "--no-remote" ];
  };

  safeMullvad = mkBrowser {
    name = "mullvad-browser";
    package = pkgs.mullvad-browser;
    binaryName = "mullvad-browser";
    dbusOwnName = "org.mozilla.firefox.*";
    extraArgs = [ "--no-remote" ];
  };

  mkBrowserDesktop = { name, exec, icon, comment, genericName ? null }:
    pkgs.makeDesktopItem {
      name = "safe-${name}";
      exec = "${exec} %U";
      inherit icon comment genericName;
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
    comment = "Firefox with arkenfox-based prefs and tightened local browser containment";
    genericName = "Web Browser";
  };

  safeTorDesktop = mkBrowserDesktop {
    name = "Tor Browser";
    exec = "safe-tor-browser";
    icon = "tor-browser";
    comment = "Tor Browser with tightened local browser containment";
    genericName = "Web Browser";
  };

  safeMullvadDesktop = mkBrowserDesktop {
    name = "Mullvad Browser";
    exec = "safe-mullvad-browser";
    icon = "mullvad-browser";
    comment = "Mullvad Browser with tightened local browser containment";
    genericName = "Web Browser";
  };
in {
  environment.systemPackages = lib.optionals browsersEnabled [
    safeFirefox safeTor safeMullvad safeFirefoxDesktop safeTorDesktop safeMullvadDesktop
  ];

  programs.firefox = lib.mkIf (!browsersEnabled) {
    enable = true;
    policies = {
      # Derived from vendored arkenfox baseline plus daily overrides above.
      Preferences = {
        "browser.startup.page" = 0;
        "browser.startup.homepage" = "about:blank";
        "browser.newtabpage.enabled" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.discovery.enabled" = false;
        "browser.urlbar.quicksuggest.enabled" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "app.shield.optoutstudies.enabled" = false;
        "app.normandy.enabled" = false;
        "app.normandy.api_url" = "";
        "geo.enabled" = false;
        "network.trr.mode" = 5;
        "privacy.donottrackheader.enabled" = true;
        "privacy.globalprivacycontrol.enabled" = true;
        "privacy.fingerprintingProtection" = true;
        "privacy.resistFingerprinting" = false;
        "privacy.resistFingerprinting.pbmode" = false;
        "privacy.resistFingerprinting.letterboxing" = false;
        "network.cookie.cookieBehavior" = 5;
        "network.http.referer.XOriginTrimmingPolicy" = 2;
        "browser.safebrowsing.downloads.remote.enabled" = false;
        "browser.safebrowsing.phishing.enabled" = true;
        "browser.safebrowsing.malware.enabled" = true;
        "media.peerconnection.enabled" = true;
        "media.navigator.enabled" = true;
        "browser.sessionstore.resume_from_crash" = true;
        "privacy.clearOnShutdown_v2.historyFormDataAndDownloads" = false;
        "privacy.clearOnShutdown_v2.browsingHistoryAndDownloads" = false;
      };
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
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
      DisableFirefoxAccounts = true;
      NoDefaultBookmarks = true;
    };
  };
}