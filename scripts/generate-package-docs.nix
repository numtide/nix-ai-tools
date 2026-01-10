let
  flake = builtins.getFlake (toString ./..);
  packages = builtins.attrNames (flake.packages.x86_64-linux);

  extractMetadata =
    pkg:
    let
      license = pkg.meta.license or null;
      licenseStr =
        if license == null then
          "Check package"
        else if builtins.isAttrs license && license ? spdxId then
          license.spdxId
        else if builtins.isAttrs license && license ? shortName then
          license.shortName
        else if builtins.isString license then
          license
        else
          "Check package";

      # Determine source type from sourceProvenance
      sourceProvenance = pkg.meta.sourceProvenance or null;
      sourceType =
        if sourceProvenance != null then
          if builtins.isList sourceProvenance then
            if builtins.any (s: s.shortName or "" == "fromSource") sourceProvenance then
              "source"
            else if builtins.any (s: s.shortName or "" == "binaryNativeCode") sourceProvenance then
              "binary"
            else if builtins.any (s: s.shortName or "" == "binaryBytecode") sourceProvenance then
              "bytecode"
            else
              "unknown"
          else
            "unknown"
        else
          "unknown";
    in
    {
      description = pkg.meta.description or "No description available";
      version = pkg.version or "unknown";
      license = licenseStr;
      homepage = pkg.meta.homepage or null;
      sourceType = sourceType;
      hideFromDocs = pkg.passthru.hideFromDocs or false;
      hasMainProgram = builtins.hasAttr "mainProgram" pkg.meta;
      category = pkg.passthru.category or "Uncategorized";
    };

  results = builtins.listToAttrs (
    builtins.map (name: {
      name = name;
      value =
        let
          pkg = flake.packages.x86_64-linux.${name} or null;
          metadata = if pkg != null then extractMetadata pkg else null;
        in
        # Filter out packages with hideFromDocs = true or no mainProgram
        if metadata != null && !(metadata.hideFromDocs or false) && (metadata.hasMainProgram or false) then
          metadata
        else
          null;
    }) packages
  );
in
results
