# Filters `package-lock.json` down to the entries npm would install on this
# host. `importNpmLock` fetches every entry the lock lists, including the
# optional platform binaries for other operating systems and CPU architectures:
# it applies none of npm's `os`/`cpu` constraints itself. Dropping them before
# evaluation keeps them out of `npmDeps`, which is what the build installs
# anyway.
#
# npm's rules are the specification: an absent field means "any host", a
# positive entry means "only these", and a `!` entry excludes. The platform
# fields come from each package's own manifest, so this needs no list of
# packages to maintain — a binary published for a new platform arrives with its
# own `os`/`cpu` and is dropped without an edit here.
{ lib, stdenv }:
src:
let
  host = stdenv.hostPlatform;

  # npm's spellings of these, which do not match nixpkgs' triple names.
  hostOs =
    if host.isLinux then
      "linux"
    else if host.isDarwin then
      "darwin"
    else if host.isWindows then
      "win32"
    else if host.isFreeBSD then
      "freebsd"
    else
      null;

  hostCpu =
    if host.isx86_64 then
      "x64"
    else if host.isAarch64 then
      "arm64"
    else if host.isAarch32 then
      "arm"
    else if host.isx86 then
      "ia32"
    else if host.isPowerPC64 then
      "ppc64"
    else if host.isS390x then
      "s390x"
    else
      null;

  # `want == null` is a host this file has no spelling for, where filtering is
  # skipped rather than everything dropped.
  allows =
    want: constraints:
    let
      positives = lib.filter (s: !(lib.hasPrefix "!" s)) constraints;
      excluded = map (lib.removePrefix "!") (lib.filter (lib.hasPrefix "!") constraints);
    in
    want == null || (!(lib.elem want excluded) && (positives == [ ] || lib.elem want positives));

  # `libc` is deliberately unchecked: no package in this lock declares it, and
  # keeping a package npm would skip only costs bytes, while dropping one npm
  # installs breaks the build.
  supports = module: allows hostOs (module.os or [ ]) && allows hostCpu (module.cpu or [ ]);

  lock = lib.importJSON (src + "/package-lock.json");
  kept = lib.filterAttrs (_: supports) lock.packages;

  # A dependency map names packages, not paths, so a name is only droppable
  # when no kept entry provides it. An entry's own `name` covers workspace
  # packages, whose path (`packages/server`) has no `node_modules/` component.
  nameOf =
    path: module:
    if lib.hasInfix "node_modules/" path then
      lib.last (lib.splitString "node_modules/" path)
    else
      module.name or null;
  provided = lib.filter (name: name != null) (lib.mapAttrsToList nameOf kept);

  # Leave no dangling reference. npmConfigHook installs from this lock with
  # `npm config set offline true`, so a name that is gone would send npm to the
  # registry for a tarball it cannot fetch. The lock records the platform
  # variants as `optionalDependencies` of their parent, so the parent has to
  # stop asking for them.
  scrubDeps = deps: lib.filterAttrs (name: _: lib.elem name provided) deps;
  scrub =
    module:
    lib.foldl'
      (
        acc: field:
        if builtins.hasAttr field acc then acc // { ${field} = scrubDeps acc.${field}; } else acc
      )
      module
      [
        "dependencies"
        "optionalDependencies"
        "devDependencies"
        "peerDependencies"
      ];
in
lock // { packages = lib.mapAttrs (_: scrub) kept; }
