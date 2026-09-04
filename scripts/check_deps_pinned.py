#!/usr/bin/env python3
"""校验 cmake/Dependencies.cmake 中所有依赖引用均已钉死。

源码依赖(add_dependency / add_header_dependency):GIT_TAG 必须是 40 位
commit SHA 或三段版本 tag;禁止分支名(main/master/develop)、HEAD 等浮动引用。

二进制依赖(add_binary_dependency):URL_HASH 必须是 SHA256=<64 位十六进制>;
占位符(如 <填入哈希>)会被拒绝,强制回填真实哈希(供应链校验)。

凡用 URL 源的依赖(任意类型)都必须带合法 URL_HASH。

退出码 0 = 通过,1 = 发现未钉死的引用。
"""
import pathlib
import re
import sys

SHA = re.compile(r"^[0-9a-f]{40}$", re.IGNORECASE)
TAG = re.compile(r"^v?\d+\.\d+\.\d+")            # 至少三段版本号
URL_HASH = re.compile(r"^SHA256=[0-9a-fA-F]{64}$")
FLOATING = {"HEAD", "main", "master", "develop", "dev", "trunk"}


def main() -> int:
    manifest = pathlib.Path("cmake/Dependencies.cmake")
    if not manifest.exists():
        print(f"[check_deps] 清单不存在: {manifest}", file=sys.stderr)
        return 1

    bad = []
    current = None          # 当前依赖名
    is_binary = False       # 当前依赖是否为 add_binary_dependency(URL 源,必带哈希)
    has_hash = False        # 是否已见合法 URL_HASH

    def finalize():
        nonlocal current, is_binary, has_hash
        if current and is_binary and not has_hash:
            bad.append(f"  {current}: 缺少合法 URL_HASH SHA256=<64hex>")
        current = None
        is_binary = False
        has_hash = False

    for line in manifest.read_text(encoding="utf-8").splitlines():
        stripped = line.split("#", 1)[0]

        # 三类依赖(add_binary_dependency 必先匹配,避免被 add_dependency 误吞):
        #   add_binary_dependency -> URL 源,必带 URL_HASH
        #   add_header_dependency -> 源码(GIT_TAG)或 URL;header-only 无构建脚本
        #   add_dependency       -> 源码(GIT_TAG)或 URL
        m_bin = re.match(r"\s*add_binary_dependency\(\s*(\S+)", stripped)
        if m_bin:
            finalize(); current = m_bin.group(1); is_binary = True;  has_hash = False; continue
        m_hdr = re.match(r"\s*add_header_dependency\(\s*(\S+)", stripped)
        if m_hdr:
            finalize(); current = m_hdr.group(1); is_binary = False; has_hash = False; continue
        m_dep = re.match(r"\s*add_dependency\(\s*(\S+)", stripped)
        if m_dep:
            finalize(); current = m_dep.group(1); is_binary = False; has_hash = False; continue

        if not current:
            continue

        # URL_HASH 校验:任何依赖凡用 URL 源都必须带合法 SHA256(供应链)
        m_hash = re.search(r"URL_HASH\s+[\"']?(\S+)", stripped)
        if m_hash:
            val = m_hash.group(1).strip("\"')")
            if URL_HASH.fullmatch(val):
                has_hash = True
            else:
                bad.append(f"  {current}: URL_HASH 非合法 SHA256=<64hex> -> {val!r}")

        # GIT_TAG 校验:非二进制依赖(源码 / header-only)的 GIT 引用必须钉死
        if not is_binary:
            m_tag = re.search(r"GIT_TAG\s+[\"']?([^\"'\s)]+)", stripped)
            if m_tag:
                val = m_tag.group(1)
                if val in FLOATING or not (SHA.fullmatch(val) or TAG.fullmatch(val)):
                    bad.append(f"  {current}: GIT_TAG={val!r}")

    finalize()

    if bad:
        print("[check_deps] 发现未钉死的依赖引用:", file=sys.stderr)
        for b in bad:
            print(b, file=sys.stderr)
        print("  源码/header 依赖:git ls-remote <url> refs/tags/<tag> 取 SHA;", file=sys.stderr)
        print("  二进制依赖:certutil -hashfile <zip> SHA256 取哈希。", file=sys.stderr)
        return 1

    print("[check_deps] 所有依赖引用均已钉死")
    return 0


if __name__ == "__main__":
    sys.exit(main())
