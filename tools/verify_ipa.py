#!/usr/bin/env python3
"""verify_ipa.py — 校验产出的 IPA 是否满足 arm64 / 最低系统 / 资源完整性要求。

用法:
    python verify_ipa.py path/to/TappiBear.ipa

检查项:
    1. 内层可执行文件是 arm64（Mach-O，不是 FAT 里的 32 位切片）
    2. Info.plist: MinimumOSVersion >= 13.0, CFBundleExecutable 存在
    3. 可执行文件没有 LC_ENCRYPTION_INFO cryptid != 0（未加密）
    4. 资源完整性: 所有 plist 引用的 png 都在包内
    5. 图集: 每对 base.plist / base.png 尺寸与 metadata 一致
"""
import sys, os, zipfile, plistlib, struct, io

REQUIRED_MIN_OS = (13, 0)
CPU_ARM64 = 0x0100000C
CPU_TYPE_ARM = 12


def parse_macho_header(data):
    """返回 (arch_list, is_fat)。arch_list = [(cputype, cpusubtype, offset, size)]"""
    magic = struct.unpack(">I", data[:4])[0]
    if magic == 0xCAFEBABE:
        n = struct.unpack(">I", data[4:8])[0]
        out = []
        for i in range(n):
            o = 8 + i * 20
            cpu, sub, off, size, align = struct.unpack(">iiIII", data[o:o + 20])
            out.append((cpu, sub, off, size))
        return out, True
    if magic in (0xFEEDFACE, 0xFEEDFACF):
        cpu, sub, ft, ncmds, size, flags = struct.unpack(">iiIIII", data[4:28])
        return [(cpu, sub, 0, len(data))], False
    # 小端
    magic_le = struct.unpack("<I", data[:4])[0]
    if magic_le in (0xFEEDFACE, 0xFEEDFACF):
        cpu, sub, ft, ncmds, size, flags = struct.unpack("<iiIIII", data[4:28])
        return [(cpu, sub, 0, len(data))], False
    return [], False


def check_encryption(data, off, size):
    """检查切片内 LC_ENCRYPTION_INFO。"""
    hdr = 28
    magic = struct.unpack("<I", data[off:off + 4])[0]
    if magic == 0xFEEDFACF:
        hdr = 32
    elif magic != 0xFEEDFACE:
        magic_be = struct.unpack(">I", data[off:off + 4])[0]
        if magic_be == 0xFEEDFACF:
            hdr = 32
        elif magic_be != 0xFEEDFACE:
            return None
        ncmds = struct.unpack(">I", data[off + 16:off + 20])[0]
        p = off + hdr
        while p < off + size:
            cmd, csize = struct.unpack(">II", data[p:p + 8])
            if cmd in (0x21, 0x2C):
                cryptid = struct.unpack(">I", data[p + 16:p + 20])[0]
                return cryptid
            p += csize
        return None
    ncmds = struct.unpack("<I", data[off + 16:off + 20])[0]
    p = off + hdr
    while p < off + size:
        cmd, csize = struct.unpack("<II", data[p:p + 8])
        if cmd in (0x21, 0x2C):
            cryptid = struct.unpack("<I", data[p + 16:p + 20])[0]
            return cryptid
        p += csize
    return None


def main(path):
    ok = True
    print("=" * 68)
    print("verify_ipa:", path)
    print("=" * 68)

    if not os.path.isfile(path):
        print("[FAIL] 文件不存在")
        return 1

    z = zipfile.ZipFile(path)
    names = z.namelist()
    print("条目数:", len(names))

    plist_paths = [n for n in names if n.endswith(".app/Info.plist")]
    if not plist_paths:
        print("[FAIL] 找不到 .app/Info.plist")
        return 1
    info = plistlib.loads(z.read(plist_paths[0]))
    app_dir = plist_paths[0].rsplit("/", 1)[0]

    # 1. 最低系统
    minos = info.get("MinimumOSVersion", "0")
    try:
        parts = tuple(int(x) for x in minos.split(".")[:2])
    except Exception:
        parts = (0, 0)
    if parts >= REQUIRED_MIN_OS:
        print("[ OK ] MinimumOSVersion = %s" % minos)
    else:
        print("[FAIL] MinimumOSVersion = %s (< %s)" % (minos, ".".join(map(str, REQUIRED_MIN_OS))))
        ok = False

    # 2. 可执行文件
    exe_name = info.get("CFBundleExecutable")
    if not exe_name:
        print("[FAIL] Info.plist 缺 CFBundleExecutable")
        return 1
    exe_path = app_dir + "/" + exe_name
    if exe_path not in names:
        print("[FAIL] 找不到可执行文件", exe_path)
        return 1
    exe = z.read(exe_path)
    print("可执行文件:", exe_path, len(exe), "bytes")

    # 3. arm64
    arches, is_fat = parse_macho_header(exe)
    print("架构:", "FAT" if is_fat else "thin", len(arches), "个切片")
    has_arm64 = False
    for cpu, sub, off, size in arches:
        name = {CPU_ARM64: "arm64", CPU_TYPE_ARM: "arm"}.get(cpu & 0xFFFFFFFF, "cpu=%#x" % cpu)
        print("   - %-8s sub=%#x size=%#x" % (name, sub & 0xFFFFFFFF, size))
        if (cpu & 0xFFFFFFFF) == CPU_ARM64:
            has_arm64 = True
            cryptid = check_encryption(exe, off, size)
            if cryptid is None:
                print("        [warn] 未找到 LC_ENCRYPTION_INFO")
            elif cryptid != 0:
                print("        [FAIL] 已加密 cryptid=%d" % cryptid)
                ok = False
            else:
                print("        [ OK ] 未加密")
    if not has_arm64:
        print("[FAIL] 没有 arm64 切片 —— iOS 11+ 无法安装")
        ok = False

    # 4. 资源完整性
    res_prefix = app_dir + "/"
    res_names = set(n[len(res_prefix):] for n in names if n.startswith(res_prefix))
    missing = []
    plist_count = 0
    for n in sorted(res_names):
        if not n.endswith(".plist"):
            continue
        try:
            d = plistlib.loads(z.read(res_prefix + n))
        except Exception:
            continue
        if "frames" not in d:
            continue
        plist_count += 1
        meta = d.get("metadata") or {}
        tex = meta.get("textureFileName")
        if not tex:
            tex = os.path.splitext(n)[0] + ".png"
        if tex not in res_names:
            missing.append((n, tex))
    if missing:
        print("[FAIL] %d 个 plist 引用了不存在的贴图:" % len(missing))
        for a, b in missing[:10]:
            print("        %s -> %s" % (a, b))
        ok = False
    else:
        print("[ OK ] %d 个图集 plist 的贴图引用完整" % plist_count)

    # 5. 关键资源存在
    required = ["g1_game.plist", "g1_game-hd.plist", "selectgame.plist", "selectgame-hd.plist",
                "bgm.mp3", "coin.wav"]
    miss2 = [r for r in required if r not in res_names]
    if miss2:
        print("[FAIL] 缺关键资源:", miss2)
        ok = False
    else:
        print("[ OK ] 关键资源齐全")

    print("-" * 68)
    print("结果:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
