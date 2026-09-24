#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR

build() {
    # 遍历所有输入参数
    for input in "$@"; do
        echo "Processing ${input}"

        if [[ -d "${input}" ]]; then
            # 如果 input 是一个目录，遍历目录下的所有 .md 文件
            for file in "${input}"/*.md; do
                build "${file}"
            done
        else
            # 如果 input 文件没有.md 后缀，就添加一个
            input="${input%.md}.md"

            # 检查 input 文件是否存在
            if [[ ! -f "${input}" ]]; then
                echo "Error: Input file ${input} does not exist"
                # 打印错误但不退出，继续处理下一个文件/目录
                continue
            fi

            # output 文件取 input 文件的前缀（不要 .md 后缀），添加 .html 后缀
            output="${input%.md}.html"

            pandoc "${input}" \
                --template="${SCRIPT_DIR}/my-template.html" \
                --standalone \
                --toc \
                --syntax-highlighting=tango \
                --lua-filter="${SCRIPT_DIR}/md-to-html.lua" \
                -o "${output}"
            echo "Built ${output}"
        fi
    done
}

usage() {
    # 至少有一个参数，允许有多个输入参数，参数可以是文件，也可以是目录
    echo "Usage: $0 <input> [input2] ..."
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

build "$@"

# 可选的主题 #
# --syntax-highlighting 接受的主题名和原来一样，常用的有 pygments（默认）、tango、espresso、zenburn、kate、monochrome、breezedark、haddock 等。
# 两个特殊值也仍然有效：
# --syntax-highlighting=none：完全关闭语法高亮
# --syntax-highlighting=idiomatic：使用输出格式原生的高亮方式（而不是 Pandoc 内置的 Skylighting）
