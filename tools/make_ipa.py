#!/usr/bin/env python3
"""make_ipa.py — 把 xcodebuild 产物打包成未签名 IPA。

用法:
    python make_ipa.py <build-dir> <output.ipa>

build-dir 里应该有 All_In_One.app（xcodebuild -derivedDataPath 的产物）。
"""
import sys, os, shutil, zipfile, subprocess, glob


def find_app(build_dir):
    cands = glob.glob(os.path.join(build_dir, "**", "*.app"), recursive=True)
    cands = [c for c in cands if os.path.isdir(c)]
    if not cands:
        return None
    # 优先叫 All_In_One.app 的
    for c in cands:
        if os.path.basename(c) == "All_In_One.app":
            return c
    return cands[0]


def main(build_dir, out_ipa):
    app = find_app(build_dir)
    if not app:
        print("FAIL: 在 %s 里找不到 .app" % build_dir)
        return 1
    print("app:", app)

    stage = os.path.join(os.path.dirname(os.path.abspath(out_ipa)), "_ipa_stage")
    if os.path.isdir(stage):
        shutil.rmtree(stage)
    payload = os.path.join(stage, "Payload")
    os.makedirs(payload)
    dst = os.path.join(payload, os.path.basename(app))
    shutil.copytree(app, dst, symlinks=True)

    # 去掉签名残留（未签名包）
    for root, dirs, files in os.walk(dst):
        for d in list(dirs):
            if d == "_CodeSignature":
                shutil.rmtree(os.path.join(root, d))
                dirs.remove(d)

    if os.path.exists(out_ipa):
        os.remove(out_ipa)
    with zipfile.ZipFile(out_ipa, "w", zipfile.ZIP_DEFLATED) as z:
        for root, dirs, files in os.walk(stage):
            for f in files:
                p = os.path.join(root, f)
                arc = os.path.relpath(p, stage)
                z.write(p, arc)

    shutil.rmtree(stage)
    size = os.path.getsize(out_ipa)
    print("wrote %s (%.1f MB)" % (out_ipa, size / 1024 / 1024))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
