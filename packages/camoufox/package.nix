{
  lib,
  stdenv,
  buildMozillaMach,
  fetchFromGitHub,
  fetchurl,
}:

let
  source = import ./source.nix { };

  upstreamSrc = fetchFromGitHub source.upstream;
  firefoxSrc = fetchurl {
    url = "https://archive.mozilla.org/pub/firefox/releases/${source.firefox.version}/source/firefox-${source.firefox.version}.source.tar.xz";
    hash = source.firefox.hash;
  };

  patchTree = upstreamSrc + "/patches";
  settingsSource = upstreamSrc + "/settings";
  additionsSource = upstreamSrc + "/additions";

  linuxMozTarget =
    let
      cpuName = stdenv.hostPlatform.parsed.cpu.name or null;
    in
    if cpuName == "aarch64" || cpuName == "arm64" then
      "aarch64-unknown-linux-gnu"
    else if cpuName == "i686" then
      "i686-pc-linux-gnu"
    else if cpuName == "x86_64" then
      "x86_64-pc-linux-gnu"
    else
      throw "Unsupported Linux moz target CPU: ${toString cpuName}";

  listPatchFiles =
    dir:
    let
      entries = builtins.readDir dir;
      names = builtins.attrNames entries;
    in
    lib.concatMap (
      name:
      let
        entryType = entries.${name};
        path = dir + "/${name}";
      in
      if entryType == "directory" then
        listPatchFiles path
      else if entryType == "regular" && lib.hasSuffix ".patch" name then
        [ path ]
      else
        [ ]
    ) names;

  toRelativePatchPath = path: lib.removePrefix "${toString patchTree}/" (toString path);

  orderedPatchPaths =
    let
      patchRecords = map (
        path:
        let
          relativePath = toRelativePatchPath path;
        in
        {
          inherit path relativePath;
          baseName = baseNameOf relativePath;
          isRoverfox = lib.hasInfix "roverfox" relativePath;
        }
      ) (listPatchFiles patchTree);

      patchSortKey = patchRecord: "${patchRecord.baseName}	${patchRecord.relativePath}";
      sortedPatchRecords = builtins.sort (a: b: patchSortKey a < patchSortKey b) patchRecords;
    in
    map (patchRecord: patchRecord.path) (
      builtins.filter (patchRecord: !patchRecord.isRoverfox) sortedPatchRecords
      ++ builtins.filter (patchRecord: patchRecord.isRoverfox) sortedPatchRecords
    );

  generatedMozconfig =
    builtins.replaceStrings
      [
        ''
          ac_add_options --enable-bootstrap
        ''
        "ac_add_options --enable-bootstrap"
      ]
      [ "" "" ]
      (builtins.readFile (upstreamSrc + "/assets/base.mozconfig"))
    + ''

      ac_add_options --target=${linuxMozTarget}
    ''
    + builtins.readFile (upstreamSrc + "/assets/linux.mozconfig");

  generatedMozconfigFile = builtins.toFile "camoufox-linux.mozconfig" generatedMozconfig;
in
(buildMozillaMach rec {
  pname = "camoufox";
  version = source.firefox.version;
  packageVersion = source.version;

  applicationName = "Camoufox";
  binaryName = "camoufox";
  src = firefoxSrc;

  requireSigning = false;
  allowAddonSideload = true;
  branding = "browser/branding/camoufox";

  unpackPhase = ''
    runHook preUnpack

    if [ -z "''${srcs:-}" ]; then
      if [ -z "''${src:-}" ]; then
        echo 'variable $src or $srcs should point to the source'
        exit 1
      fi
      srcs="$src"
    fi

    srcsArray=()
    concatTo srcsArray srcs

    dirsBefore=""
    for i in *; do
      if [ -d "$i" ]; then
        dirsBefore="$dirsBefore $i "
      fi
    done

    for i in "''${srcsArray[@]}"; do
      unpackFile "$i"
    done

    : "''${sourceRoot=}"

    if [ -n "''${setSourceRoot:-}" ]; then
      runOneHook setSourceRoot
    elif [ -z "$sourceRoot" ]; then
      for i in *; do
        if [ -d "$i" ]; then
          case $dirsBefore in
            *\ $i\ *)
              ;;
            *)
              if [ -n "$sourceRoot" ]; then
                echo "unpacker produced multiple directories"
                exit 1
              fi
              sourceRoot="$i"
              ;;
          esac
        fi
      done
    fi

    if [ -z "$sourceRoot" ]; then
      echo "unpacker appears to have produced no directories"
      exit 1
    fi

    echo "source root is $sourceRoot"

    if [ "''${dontMakeSourcesWritable:-0}" != 1 ]; then
      chmod -R u+w -- "$sourceRoot"
    fi

    mkdir -p \
      "$sourceRoot/services/settings/dumps/main" \
      "$sourceRoot/build/vs" \
      "$sourceRoot/lw"

    cp -f "${upstreamSrc}/assets/search-config.json" "$sourceRoot/services/settings/dumps/main/search-config.json"
    cp -f "${upstreamSrc}/patches/librewolf/pack_vs.py" "$sourceRoot/build/vs/pack_vs.py"

    cp -f "${settingsSource}/camoufox.cfg" "$sourceRoot/lw/camoufox.cfg"
    cp -f "${settingsSource}/distribution/policies.json" "$sourceRoot/lw/policies.json"
    cp -f "${settingsSource}/defaults/pref/local-settings.js" "$sourceRoot/lw/local-settings.js"
    cp -f "${settingsSource}/chrome.css" "$sourceRoot/lw/chrome.css"
    cp -f "${settingsSource}/properties.json" "$sourceRoot/lw/properties.json"
    cp -f "${upstreamSrc}/scripts/mozfetch.sh" "$sourceRoot/lw/mozfetch.sh"
    : > "$sourceRoot/lw/moz.build"

    cp -R "${additionsSource}/." "$sourceRoot/"
    cp -f ${generatedMozconfigFile} "$sourceRoot/mozconfig"

    for versionFile in \
      "$sourceRoot/browser/config/version.txt" \
      "$sourceRoot/browser/config/version_display.txt"
    do
      printf '%s\n' '${source.version}' > "$versionFile"
    done

    chmod -R u+w -- "$sourceRoot"

    runHook postUnpack
  '';

  extraPatches = orderedPatchPaths;

  extraConfigureFlags = [
    "--disable-backgroundtasks"
    "--disable-default-browser-agent"
    "--disable-system-policies"
    "--with-unsigned-addon-scopes=app,system"
    "--target=${linuxMozTarget}"
  ];

  meta = {
    description = "Camoufox browser built from a patched Firefox source tree";
    homepage = "https://github.com/${source.upstream.owner}/${source.upstream.repo}";
    license = lib.licenses.mpl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.linux;
    mainProgram = binaryName;
  };
}).override
  {
    enableDebugSymbols = false;
    crashreporterSupport = false;
    enableOfficialBranding = false;
    ltoSupport = false;
    pgoSupport = false;
  }
