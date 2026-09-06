## Glob 模式匹配

GLOB 模式（通配符模式）是一种用于匹配文件路径或文件名集合的字符串语法。它常被用在命令行（如 `ls *.txt`）、配置文件（如 .gitignore）以及各类编程语言中。它的核心设计理念是“所见即所得”——比正则表达式（Regex）简单得多，专门为文件系统设计。

### 核心基础语法

| 通配符 | 含义 | 示例 |
| -- | -- | -- |
| `*` | 匹配任意数量的字符（包括 0 个），但不匹配路径分隔符（`/` 或 `\`） | `*.js` 匹配 `app.js`、`index.js`，但不匹配 `src/app.js` |
| `?` | 匹配恰好 1 个字符（不包括路径分隔符） | `file?.txt` 匹配 `file1.txt`、`fileA.txt`，不匹配 `file10.txt` |
| `[abc]` | 匹配方括号内的任意 1 个字符（范围可用 `[a-z]`） | `file[0-9].txt` 匹配 `file1.txt`，不匹配 `fileA.txt` |
| `[!abc]` | 匹配不在方括号内的任意 1 个字符 | `file[!0-9].txt` 匹配 `fileA.txt`，不匹配 `file1.txt` |

### 扩展语法

现代 GLOB 库（如 minimatch、node-glob）支持以下增强语法，这也是 `.gitignore` 和 `.dockerignore` 实际采用的规则：

| 通配符 | 含义 | 匹配示例 |
| -- | -- | -- |
| `**` | 匹配任意层级的目录（包括 0 层） | `src/**/*.js` 匹配 `src/app.js`、`src/lib/helper.js` |
| `{a,b,c}` | 匹配大括号中的任意一个模式（逗号分隔） | `*.{jpg,png}` 匹配 `a.jpg` 和 `b.png` |
| `!(pattern)` | 排除某个模式（取反） | `!(node_modules)/*.js` 匹配除 `node_modules` 外的目录下的 js 文件 |
| `?(pattern)` | 匹配模式 0 次或 1 次 | `a?(b).js` 匹配 `a.js` 和 `ab.js` |
| `+(pattern)` | 匹配模式 1 次或多次 | `a+(b).js` 匹配 `ab.js`、`abb.js`，不匹配`a.js` |
| `*(pattern)` | 匹配模式 0 次或多次 | `a*(b).js` 匹配 `a.js`、`ab.js`、`abb.js` |

### filepath 包

Go 标准库提供了 [filepath](https://pkg.go.dev/path/filepath#pkg-overview) 包，用于跨平台路径操作（Join、Clean、Base、Dir、Ext、Walk、Split 等），其中包含 Glob 模式匹配功能。

[func Glob(pattern string) (matches []string, err error)](https://pkg.go.dev/path/filepath#Glob)，特点：
  
- 基础匹配：支持`*`、`?` 和 `[]` 等基础通配符
- 不递归：不支持 `**` 语法来匹配多级子目录
- 用途局限：主要设计用于路径匹配，不适用于任意字符串的匹配

```go
func main() {
 // 匹配当前目录下所有 .go 文件
 matches, _ := filepath.Glob("*.go")
 for _, p := range matches {
  fmt.Println(p)
 }
}
```

Glob 底层是通过 filepath.Match(pattern, name) 来做模式匹配的。Match 是更纯粹的字符串级别匹配（但同样不跨分隔符），在某些不需要访问文件系统的场景下很有用。

[func Match(pattern, name string) (matched bool, err error)](https://pkg.go.dev/path/filepath#Match)

### 注意事项

1. `.` 开头的隐藏文件：在 Unix/Linux 中，`*` 默认不匹配以 `.` 开头的文件，若要匹配，需显式写 `.*`
2. 路径分隔符：Windows 上的 `\` 在 GLOB 库中通常会被自动转换为 `/`，所以在写模式时统一使用 `/` 最安全
