#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR

BOOK_ROOT="$(dirname "${SCRIPT_DIR}")"
readonly BOOK_ROOT

# 左侧「总体目录」的临时文件，通过 --include-before-body 注入到模板
SIDEBAR_FILE=""

# 将目录名中的中文数字映射为排序键（前言=0，第一~十二部分=1~12，未知=99）
part_key() {
    local name="$1" num
    case "${name}" in
        前言) printf '0\n'; return ;;
        第*部分) num="${name#第}"; num="${num%部分}" ;;
        *) printf '99\n'; return ;;
    esac
    case "${num}" in
        一) printf '1\n';; 二) printf '2\n';; 三) printf '3\n';; 四) printf '4\n';;
        五) printf '5\n';; 六) printf '6\n';; 七) printf '7\n';; 八) printf '8\n';;
        九) printf '9\n';; 十) printf '10\n';; 十一) printf '11\n';; 十二) printf '12\n';;
        *) printf '99\n';;
    esac
}

# 提取 markdown 文件首个标题（#、## … 任意层级），并做最小 HTML 转义
extract_title() {
    local file="$1"
    grep -m1 -E '^#{1,6}[[:space:]]' "${file}" 2>/dev/null \
        | sed -E 's/^#{1,6}[[:space:]]+//' \
        | sed -e 's/`//g' \
        | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# 生成全书导航：前言 + 各部分 index + 各部分章节
generate_sidebar() {
    local book_root="$1" out="$2"
    local name d index_file title chapter cname ctitle

    {
        printf '%s\n' '<aside class="sidebar" id="sidebar">'
        printf '%s\n' '<nav class="sidebar-nav">'

        while IFS=$'\t' read -r _ name; do
            [[ -z "${name}" ]] && continue
            index_file="${book_root}/${name}/index.md"
            title=""
            [[ -f "${index_file}" ]] && title="$(extract_title "${index_file}")"
            [[ -z "${title}" ]] && title="${name}"

            printf '%s\n' '<div class="nav-group">'
            if [[ -f "${index_file}" ]]; then
                printf '<a class="nav-group-title" href="../%s/index.html">%s</a>\n' "${name}" "${title}"
            else
                printf '<span class="nav-group-title">%s</span>\n' "${title}"
            fi

            for chapter in "${book_root}/${name}/"*.md; do
                [[ -e "${chapter}" ]] || continue
                cname="$(basename "${chapter}")"
                [[ "${cname}" == "index.md" ]] && continue
                cname="${cname%.md}"
                ctitle="$(extract_title "${chapter}")"
                [[ -z "${ctitle}" ]] && ctitle="${cname}"
                printf '<a class="nav-item" href="../%s/%s.html">%s</a>\n' "${name}" "${cname}" "${ctitle}"
            done

            printf '%s\n' '</div>'
        done < <(for d in "${book_root}"/*/; do
            name="$(basename "${d}")"
            case "${name}" in
                scripts|.*) continue ;;
            esac
            printf '%s\t%s\n' "$(part_key "${name}")" "${name}"
        done | sort -n -t$'\t' -k1,1)

        printf '%s\n' '</nav>'
        printf '%s\n' '</aside>'
    } > "${out}"
}

build() {
    local input file dir output

    # 遍历所有输入参数
    for input in "$@"; do
        echo "Processing ${input}"

        if [[ -d "${input}" ]]; then
            # 遍历 input 目录下的所有 .md 文件
            for file in "${input}"/*.md; do
                [[ -f "${file}" ]] || continue
                build "${file}"
            done

            # 递归遍历 input 目录的子目录（跳过普通文件）
            for dir in "${input}"/*; do
                [[ -d "${dir}" ]] || continue
                build "${dir}"
            done
        else
            # 如果 input 文件有后缀名但不是 .md 文件，就忽略
            if [[ "${input}" != *.md && "${input}" == *.* ]]; then
                echo "Error: skip non-markdown file ${input}" >&2
                continue
            fi

            # 如果 input 文件没有 .md 后缀，就添加一个
            input="${input%.md}.md"

            # 检查 input 文件是否存在
            if [[ ! -f "${input}" ]]; then
                echo "Error: Input file ${input} does not exist"
                # 打印错误但不退出，继续处理下一个文件/目录
                continue
            fi

            # output 文件取 input 文件的前缀（不要 .md 后缀），添加 .html 后缀
            output="${input%.md}.html"

            if ! pandoc "${input}" \
                --template="${SCRIPT_DIR}/my-template.html" \
                --standalone \
                --toc \
                --syntax-highlighting=tango \
                --lua-filter="${SCRIPT_DIR}/md-to-html.lua" \
                --include-before-body="${SIDEBAR_FILE}" \
                -o "${output}"; then
                echo "Error: failed to build ${input}" >&2
                continue
            fi
            
            echo "Built ${output}"
        fi
    done
}

usage() {
    # 至少有一个参数，允许有多个输入参数，参数可以是 .md 文件，也可以是目录（递归处理）
    echo "Usage: $0 <input> [input2] ..."
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

SIDEBAR_FILE="$(mktemp)"
trap 'rm -f "${SIDEBAR_FILE}"' EXIT
generate_sidebar "${BOOK_ROOT}" "${SIDEBAR_FILE}"

build "$@"

# 可选的主题 #
# --syntax-highlighting 接受的主题名和原来一样，常用的有 pygments（默认）、tango、espresso、zenburn、kate、monochrome、breezedark、haddock 等。
# 两个特殊值也仍然有效：
# --syntax-highlighting=none：完全关闭语法高亮
# --syntax-highlighting=idiomatic：使用输出格式原生的高亮方式（而不是 Pandoc 内置的 Skylighting）
