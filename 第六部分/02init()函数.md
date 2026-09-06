
## init() 函数

```go
func init() {
    // 初始化逻辑
}
```

`init()` 是用于包初始化的特殊函数，每个源文件可定义多个 `init()` 函数。特点：

- 无参数、无返回值，无法返回错误，失败时只能 `panic()` 或 `os.Exit()`
- 自动在程序启动时执行，不能被显式调用

### 初始化顺序

Go 规范明确定义了 `init()` 的执行顺序：

- 跨包：按 import 依赖关系，被依赖的包先初始化
- 包内：按源文件名字母顺序执行
- 文件内：按 init() 声明顺序执行

完整的初始化顺序：

- 导入的包（按依赖关系递归处理）
- 当前包级常量/变量初始化（按声明顺序和依赖关系）
- 当前包的 init() 函数
- main() 函数

模块中多个包的初始化顺序由导入顺序和依赖关系决定，无显式依赖时顺序不确定。

示例目录结构：

```text
pkgs/   go mod init example.com/pkgs
├── cmd/
│   └── main.go
├── foo/
│   └── foo.go
├── bar/
│   └── bar.go
└── go.mod
```

```go
// cmd/main.go
package main

import (
 "fmt"

 "example.com/pkgs/bar" // 注意：这里不能用相对路径 "../bar"和 "../foo", 必须用模块路径
 "example.com/pkgs/foo"
)

func init() {
 fmt.Println("main init 1")
}

func init() {
 fmt.Println("main init 2")
}

func main() {
 foo.Foo()
 bar.Bar()
}
```

```go
// foo/foo.go
package foo

import "fmt"

func init() {
 fmt.Println("foo init 1")
}

func init() {
 fmt.Println("foo init 2")
}

func Foo() {
 fmt.Println("Foo")
}

// bar/bar.go
package bar

import "fmt"

func init() {
 fmt.Println("bar init 1")
}

func init() {
 fmt.Println("bar init 2")
}

func Bar() {
 fmt.Println("Bar")
}
```

进到 cmd 目录，执行 `go run .`，输出：

```text
bar init 1
bar init 2
foo init 1
foo init 2
main init 1
main init 2
Foo
Bar
```

虽然 `init()` 函数的执行顺序是明确的，但明确不等于易于维护。重命名文件、移动代码、调整声明顺序都可能破坏依赖关系，且编译器不会报错。阅读代码时，需要跨文件追踪 `init()` 的调用链，可读性差。所以在实际开发中应尽量避免使用 `init()`，优先使用显式初始化函数。

### 使用场景

`init()` 函数并非完全无用。当初始化逻辑需要多步操作（如初始化复杂的数据结构），但不涉及可能失败的外部资源时，可以使用 `init()`。此外，注册 `database/sql` 驱动、`image` 包注册解码格式等场景，使用 `init()` 也是惯用做法。

#### 初始化全局变量

```go
var config map[string]string

func init() {
 config = make(map[string]string)
 config["key"] = "value"
}
```

#### 注册功能（如注册数据库驱动）

```go
// database/drivers/mysql.go
func init() {
 database.Register("mysql", &MySQLDriver{})
}
```

注意：

- 避免在 `init()` 中做复杂逻辑或可能失败的操作
- 不要在 `init()` 中启动 Goroutine
