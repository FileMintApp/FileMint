#!/usr/bin/env python3
# SPDX-License-Identifier: LGPL-2.1-or-later
"""Rebuild the app-only compression XCFramework from checked-in, hashed sources.

Requires Xcode, Python 3.12+, Meson 1.10.2, Ninja, CMake 3.31.6 and pkg-config.
No network requests, installation into system locations, or Apple signing keys.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shlex
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
THIRD = ROOT / "ThirdParty/ImageCompression"
NAME = "FileMintCompression"


def run(args, env, cwd=None):
    print("+ " + shlex.join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), env=env, cwd=cwd, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tools-bin", type=Path)
    parser.add_argument("--work", type=Path, default=ROOT / "build/image-compression.noindex")
    parser.add_argument("--output", type=Path, default=ROOT / "CorePackage/Artifacts/FileMintCompression.xcframework")
    args = parser.parse_args()
    work, output = args.work.resolve(), args.output.resolve()
    if output.name != NAME + ".xcframework" or output == ROOT:
        raise SystemExit("Output must name FileMintCompression.xcframework")
    if work in (ROOT, THIRD, ROOT / "CorePackage"):
        raise SystemExit("Use a separate directory for disposable build files")
    work.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["DEVELOPER_DIR"] = env.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    if args.tools_bin:
        env["PATH"] = str(args.tools_bin.resolve()) + os.pathsep + env["PATH"]
    for tool in ["cmake", "meson", "ninja", "pkg-config"]:
        if not shutil.which(tool, path=env["PATH"]):
            raise SystemExit(f"Missing build tool: {tool}")
    pkgconfig = shutil.which("pkg-config", path=env["PATH"])
    if args.tools_bin:
        # pkgconf-pypi's Python launcher is not a native pkg-config executable
        # to Meson. Its wheel also carries the standalone executable.
        native_pkgconf = list(args.tools_bin.resolve().parent.glob("lib/python*/site-packages/pkgconf/.bin/pkgconf"))
        if native_pkgconf:
            pkgconfig = str(native_pkgconf[0])
    sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], env=env, text=True).strip()
    cc = subprocess.check_output(["xcrun", "--find", "clang"], env=env, text=True).strip()
    cxx = subprocess.check_output(["xcrun", "--find", "clang++"], env=env, text=True).strip()
    prefix, source_root = work / "prefix", work / "source"
    prefix.mkdir(exist_ok=True)
    source_root.mkdir(exist_ok=True)
    locked = json.loads((THIRD / "sources.lock.json").read_text())
    sources = {}
    for entry in locked["sources"]:
        archive = THIRD / "sources" / entry["file"]
        if hashlib.sha256(archive.read_bytes()).hexdigest() != entry["sha256"]:
            raise SystemExit(f"Source checksum mismatch: {archive.name}")
        with tarfile.open(archive) as stream:
            top = stream.getmembers()[0].name.split("/")[0]
            if not top or top in (".", ".."):
                raise SystemExit("Invalid source archive root")
            extracted = source_root / top
            if extracted.is_symlink():
                raise SystemExit("Source extraction path must not be a symlink")
            if extracted.exists():
                shutil.rmtree(extracted)
            stream.extractall(source_root, filter="data")
        sources[entry["name"]] = source_root / top
    pc = work / "sdk-pkgconfig"
    pc.mkdir(exist_ok=True)
    # Only these SDK dependencies and the private prefix are discoverable.
    for name, version, lib, include in [
        ("zlib", "1.2.12", "z", ""), ("expat", "2.6.0", "expat", ""),
        ("libffi", "3.4.0", "ffi", "/ffi")
    ]:
        (pc / f"{name}.pc").write_text(
            f"Name: {name}\nDescription: macOS SDK {name}\nVersion: {version}\n"
            f"Libs: -l{lib}\nCflags: -I{sdk}/usr/include{include}\n")
    env.update({"MACOSX_DEPLOYMENT_TARGET": "13.0", "CC": cc, "CXX": cxx,
                "PKG_CONFIG": pkgconfig,
                "PKG_CONFIG_LIBDIR": f"{prefix}/lib/pkgconfig:{pc}", "PKG_CONFIG_PATH": ""})
    flags = ["-arch", "arm64", "-isysroot", sdk, "-mmacosx-version-min=13.0",
             "-I" + str(prefix / "include"), "-L" + str(prefix / "lib")]
    env["CFLAGS"] = env["CXXFLAGS"] = shlex.join(flags)
    env["LDFLAGS"] = shlex.join(flags)
    native = work / "native.ini"
    native.write_text("[binaries]\n" + f"c = {cc!r}\ncpp = {cxx!r}\n" +
        f"pkg-config = {pkgconfig!r}\n" +
        "[built-in options]\n" + "\n".join(f"{key} = {flags!r}" for key in
        ["c_args", "cpp_args", "c_link_args", "cpp_link_args"]) + "\n")
    common = ["-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release", "-DBUILD_SHARED_LIBS=OFF",
              "-DCMAKE_POSITION_INDEPENDENT_CODE=ON", "-DCMAKE_OSX_ARCHITECTURES=arm64",
              "-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0", f"-DCMAKE_OSX_SYSROOT={sdk}",
              f"-DCMAKE_INSTALL_PREFIX={prefix}", f"-DCMAKE_INSTALL_LIBDIR={prefix / 'lib'}",
              f"-DCMAKE_PREFIX_PATH={prefix}", "-DCMAKE_IGNORE_PREFIX_PATH=/opt/homebrew;/usr/local"]

    def cmake(name, options):
        build = work / ("build-" + name)
        run(["cmake", "-S", sources[name], "-B", build, *common, *options], env)
        run(["cmake", "--build", build, "--parallel", "4"], env)
        run(["cmake", "--install", build], env)

    def meson(name, options, target=None):
        build = work / ("build-" + name)
        command = ["meson", "setup"]
        if (build / "build.ninja").exists():
            command += ["--reconfigure"]
        run([*command, build, sources[name], "--native-file", native,
             "--prefix", prefix, "--libdir", "lib", "--buildtype=release",
             "--default-library=static", "--auto-features=disabled", "--wrap-mode=nofallback",
             "-Ddebug=false", "-Db_ndebug=true", *options], env)
        run(["meson", "compile", "-C", build, "-j", "4", *([target] if target else [])], env)
        tags = "devel,runtime,bin-devel" if name == "glib" else "devel" if name == "libvips" else "devel,runtime"
        run(["meson", "install", "-C", build, "--no-rebuild", "--tags", tags], env)

    cmake("pcre2", ["-DPCRE2_BUILD_PCRE2_8=ON", "-DPCRE2_BUILD_PCRE2_16=OFF",
                    "-DPCRE2_BUILD_PCRE2_32=OFF", "-DPCRE2_BUILD_PCRE2GREP=OFF",
                    "-DPCRE2_BUILD_TESTS=OFF", "-DPCRE2_SUPPORT_JIT=OFF"])
    meson("proxy-libintl", [])
    meson("glib", ["-Dtests=false", "-Dinstalled_tests=false", "-Ddocumentation=false",
                    "-Dintrospection=disabled", "-Dnls=disabled", "-Dglib_debug=disabled"])
    cmake("mozjpeg", ["-DENABLE_SHARED=OFF", "-DENABLE_STATIC=ON", "-DWITH_TURBOJPEG=OFF",
                     "-DPNG_SUPPORTED=OFF", "-DWITH_SIMD=ON"])
    cmake("libpng", ["-DPNG_SHARED=OFF", "-DPNG_STATIC=ON", "-DPNG_TESTS=OFF", "-DPNG_TOOLS=OFF"])
    cmake("libtiff", ["-Dtiff-tools=OFF", "-Dtiff-tests=OFF", "-Dtiff-contrib=OFF",
                     "-Dtiff-docs=OFF", "-Dtiff-cxx=OFF", "-Dzlib=ON", "-Djpeg=ON",
                     *[f"-D{codec}=OFF" for codec in ["jbig", "lerc", "lzma", "zstd", "webp",
                       "libdeflate", "tiff-opengl", "old-jpeg", "jpeg12"]]])
    meson("libvips", ["-Djpeg=enabled", "-Dpng=enabled", "-Dtiff=enabled", "-Dzlib=enabled",
        "-Dmodules=disabled", "-Dcplusplus=false", "-Ddeprecated=false", "-Dintrospection=disabled",
        "-Dexamples=false", "-Ddocs=false", "-Dcpp-docs=false", "-Dvapi=false",
        "-Dnsgif=false", "-Dppm=false", "-Danalyze=false", "-Dradiance=false"], "libvips/vips:static_library")

    framework = work / (NAME + ".framework")
    if framework.exists():
        shutil.rmtree(framework)
    version = framework / "Versions/A"
    for directory in ["Headers", "Modules", "Resources"]:
        (version / directory).mkdir(parents=True, exist_ok=True)
    (framework / "Versions/Current").symlink_to("A")
    for component in [NAME, "Headers", "Modules", "Resources"]:
        (framework / component).symlink_to("Versions/Current/" + component)
    header = THIRD / "bridge" / (NAME + ".h")
    shutil.copy2(header, version / "Headers" / header.name)
    (version / "Modules/module.modulemap").write_text(
        f'framework module {NAME} {{\n  umbrella header "{NAME}.h"\n  export *\n}}\n')
    info = {"CFBundleIdentifier": "io.github.daigua.filemint.compression", "CFBundleName": NAME,
            "CFBundleExecutable": NAME, "CFBundlePackageType": "FMWK", "CFBundleVersion": "1",
            "CFBundleShortVersionString": "1.0", "LSMinimumSystemVersion": "13.0"}
    (version / "Resources/Info.plist").write_bytes(plistlib.dumps(info))
    cflags = shlex.split(subprocess.check_output([pkgconfig, "--cflags", "vips"], env=env, text=True))
    libraries = shlex.split(subprocess.check_output([pkgconfig, "--static", "--libs", "vips"], env=env, text=True))
    exports = work / "exports.txt"
    exports.write_text("_fm_compression_encode\n_fm_compression_version\n")
    run([cc, *flags, "-O2", "-dynamiclib", "-fvisibility=hidden", *cflags,
         THIRD / "bridge" / (NAME + ".c"), *libraries,
         "-Wl,-dead_strip", f"-Wl,-exported_symbols_list,{exports}",
         "-install_name", f"@rpath/{NAME}.framework/Versions/A/{NAME}",
         "-o", version / NAME], env)
    run(["strip", "-S", version / NAME], env)
    notice = THIRD / "THIRD-PARTY-NOTICES.txt"
    if notice.exists():
        shutil.copy2(notice, version / "Resources" / notice.name)
    run(["codesign", "--force", "--sign", "-", "--timestamp=none", framework], env)
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        shutil.rmtree(output)
    run(["xcodebuild", "-create-xcframework", "-framework", framework, "-output", output], env)
    manifest = {"schemaVersion": 1, "architecture": "arm64", "minimumMacOS": "13.0",
                "encoders": ["MozJPEG", "libpng", "libtiff"], "sources": locked["sources"],
                "recipeFiles": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in [Path(__file__).resolve(), *sorted((THIRD / "bridge").glob("*"))]},
                "tools": {tool: subprocess.check_output([tool, "--version"], env=env, text=True).splitlines()[0]
                          for tool in ["cmake", "meson", "ninja"]},
                "files": {str(p.relative_to(output)): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sorted(output.rglob("*")) if p.is_file() and not p.is_symlink()}}
    (THIRD / "artifact-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
